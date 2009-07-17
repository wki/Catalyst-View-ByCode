package Catalyst::View::ByCode::Helper;

use strict;
use warnings;

use base qw(Exporter);

use Devel::Declare();
use Catalyst::View::ByCode::Markup;
use Catalyst::View::ByCode::Util;
use Catalyst::View::ByCode::Declare;
use HTML::Tagset;
use HTML::Entities qw(%entity2char);

our $DEBUG   = 1;
our @EXPORT_OK  = qw(clear_markup init_markup get_markup markup_object
                     doctype
                     load
                     yield
                     with fill using employ
                     attr data
                     set_global_data
                     apply
                     class id on
                     get_trail set_trail
                     stash c);
our %EXPORT_TAGS = (
    markup  => [qw(clear_markup init_markup get_markup markup_object)],
    default => [@EXPORT_OK],
);

#
# define variables
#
my $markup; # initialized with 'init_markup',
            # doing this during 'import' could be bad
my $stash;  # current stash
my $c;      # current context
my $view;   # ByCode View instance

#
# some tags get changed by simply renaming them
#
my %change_tags = ('select' => 'choice',
                   'link'   => 'link_tag',
                   'tr'     => 'trow',
                   'td'     => 'tcol',
                   'sub'    => 'subscript',
                   'sup'    => 'superscript',
               );

######################################## IMPORT
#
# just importing this module...
#
sub import {
    my $module = shift; # eat off 'Catalyst::View::ByCode::Helper';

    my $calling_package = caller;

    my $default_export = grep {$_ eq ':default'} @_;

    # warn "bycode: default_export = $default_export, caller=$calling_package";

    #
    # build HTML Tag-subs into caller's namespace
    #
    _construct_functions($calling_package)
        if ($default_export);

    #
    # do Exporter's Job on Catalyst::View::ByCode::Helper's @EXPORT
    #
    $module->export_to_level(1, $module, @_);

    #
    # create *OUT and *RAW in calling package to allow 'print' to work
    #   'print OUT' works, Components use a 'select OUT' to allow 'print' alone
    #
    no strict 'refs';
    if ($default_export) {
        tie *{"$calling_package\::OUT"}, $module, 1; # escaped:   OUT
        tie *{"$calling_package\::RAW"}, $module, 0; # unescaped: RAW
        tie *{"$calling_package\::STDOUT"}, $module, 1; # escaped: STDOUT
    }
}

######################################## FILE HANDLE MANAGEMENT
#
# IN/OUT stuff using a tied thing
#
sub TIEHANDLE {
    my $class  = shift; # my class (Catalyst::View::ByCode::Helper)
    my $handle = shift; # escaping on or off -- use this value as handle
                        # and its value to decide escaping
                        # -- see PRINT/PRINTF below

    return bless \$handle, $class;
}

sub PRINT {
    my $handle = shift;

    #_check_markup();

    if ($$handle) { # check escaping
        $markup->add_content(@_);
    } else {
        $markup->add_raw(@_);
    }

    return;
}

sub PRINTF {
    my $handle = shift;

    #_check_markup();

    if ($$handle) { # check escaping
        $markup->add_content(sprintf(@_));
    } else {
        $markup->add_raw(sprintf(@_));
    }

    return;
}

######################################## EXPORTED FUNCTIONS
#
# a simple shortcut for css/js handling
# usage:
#   load js => '/url/to/file.js';
#   load css => '/url/to/file.js';
#
#   load <<Controller_name>> => file_name [.js]
#
### FIXME: build more logic into load() -- accumulate calls
###        and resolve as late as possible
#
sub load {
    my $kind  = shift;
    
    return if (!$kind || ref($kind));

    if ($kind eq 'css') {
        #
        # simple static CSS inserted just here and now
        #
        foreach my $path (@_) {
            $markup->add_tag(link => {
                    rel  => 'stylesheet',
                    type => 'text/css',
                    href => $path,
            });
        }
    } elsif ($kind eq 'js') {
        #
        # simple static JS inserted just here and now
        #
        foreach my $path (@_) {
            $markup->add_tag(script => {
                    type => 'text/javascript',
                    src  => $path,
            });
        }
    } elsif ((my $controller = $c->controller($kind)) &&
             ($kind eq 'Js' || $kind eq 'Css')) {
        ### FIXME: are Hardcoded controller names wise???
        #
        # some other kind of load operation we have a controller for
        #
        # $c->log->debug("LOAD: kind=$kind, ref(controller)=" . ref($controller));
        if (!exists($markup->{load}->{$kind})) {
            push @{$markup->{load}->{$kind}}, @_;
            if ($kind eq 'Css') {
                $markup->add_tag(link => {
                        rel  => 'stylesheet',
                        type => 'text/css',
                        href => sub {
                            $c->uri_for($controller->action_for('default'),
                                        @{$markup->{load}->{$kind}},
                                        );
                        },
                });
            } else {
                $markup->add_tag(script => {
                        type => 'text/javascript',
                        src  => sub {
                            $c->uri_for($controller->action_for('default'),
                                        @{$markup->{load}->{$kind}},
                                        );
                        },
                });
            }
        } else {
            push @{$markup->{load}->{$kind}}, @_;
        }
    }
    
    return;
}

#
# a special sub-rendering command like Rails ;-)
#
# yield \&name_of_a_sub;
# yield a_named_yield;
# yield 'content';
# yield;   # same as 'content'
# yield 'path/to/template.pl'
# ### TODO: yield package::subname
# ### TODO: yield +package::package::package::subname
#
sub yield(;*@) {
    my $yield_name = shift || '';
    
    $c->log->debug("yield '$yield_name' executing...") if ($c->debug);

    # $c->log->debug("yield :: c= $c, stash=" . join(',', keys(%{$c->stash})) );

    # my $self = $c->stash->{current_view_instance};
    my $sub;
    if (ref($yield_name) eq 'CODE') {
        $sub = $yield_name;
    } elsif ($yield_name && exists($c->stash->{yield}->{$yield_name})) {
        #
        # a named yield we know about is requested
        #
        $sub = $c->stash->{yield}->{$yield_name};
        if (!ref($sub)) {
            $sub = $view->_compile_template($c, $sub);
        }
        $c->stash->{yield}->{$yield_name} = undef;
    } elsif (!$yield_name || lc($yield_name) eq 'content') {
        #
        # standard content - follow the yield-list
        #
        $sub = shift @{$c->stash->{yield_list}};
    } else {
        #
        # an unknown thing -- see if we know the path
        #   or the calling package knows a sub.
        #
        $sub = $view->_compile_template($c, $yield_name)
               || caller->can($yield_name);
    }

    # $c->log->debug("yield :: sub=$sub");
    $sub->(@_) if ($sub && ref($sub) eq 'CODE');

    # $c->log->debug("yield '$yield_name' done.");

    return;
}

#
# routines for collecting various things
#  - attributes (with)
#  - data (fill)
#  - manipulators (employ)
#
sub fill(&;@)   { _handle_component(undef, 'data', @_); }
sub using(&;@)  { _handle_component(undef, 'data', @_); }  ### FIXME: &using is deprecated
sub with(&;@)   { _handle_component(undef, 'attr', @_); }
sub employ(&;@) { _handle_component(undef, 'callback', @_); }

#
# the outside view of _collect to expand things
# sub my_testblock(;&@) {
#    my $code = shift;
#    apply { my $element = shift; # a hashref for a pseudo-tag (tag=undef)
#            ... some code using @_ ...
#            $code->() if ($code); 
#    } @_;
# }
#
sub apply(&;@) { _handle_component(undef, undef, @_); }

#
# set attribute(s) of latest open tag (instead of 'with' outside)
#
sub attr {
    #_check_markup();
    $markup->attr(make_hashref(@_));
}

#
# set data for latest open tag (instead of 'using' outside)
#
sub data {
    #_check_markup();
    $markup->data(make_hashref(@_));
}

#
# set global data for an ID
#
sub set_global_data {
    my $id = shift;
    my $data = shift;

    #_check_markup();
    $markup->set_data($id, $data);
}

#
# set a class inside a tag
#
sub class {
    #_check_markup();
    $markup->attr({class => ref($_[0]) eq 'ARRAY' ? shift : [@_]});
}

#
# set an ID
#
sub id {
    #_check_markup();
    $markup->attr({id => shift});
}

#
# define a javascript-handler
#
sub on {
    my $handler = shift;

    #_check_markup();
    $markup->attr({"on$handler" => [@_]});
}

#
# determine a trail
#
sub get_trail {
    my $selector = shift;

    #_check_markup();
    return $markup->get_trail($selector);
}

#
# set the starting trail for entire markup
#
sub set_trail {
    my $trail = shift;

    #_check_markup();
    $markup->set_trail($trail);
}

#
# simple getters
#
sub stash { $stash }
sub c { $c }

#
# generate a proper doctype line
#
sub doctype {
    my $kind = join(' ', @_);

    # see http://hsivonen.iki.fi/doctype/ for details on these...
    my @doctype_finder = (
        [qr(html(?:\W*4[0-9.]*)?\W*s)     => 'html4_strict'],
        [qr(html(?:\W*4[0-9.]*)?\W*[tl])  => 'html4_loose'],
        [qr(html)                         => 'html4'],

        [qr(xhtml\W*1\W*1)                => 'xhtml1_1'],
        [qr(xhtml(?:\W*1[0-9.]*)?\W*s)    => 'xhtml1_strict'],
        [qr(xhtml(?:\W*1[0-9.]*)?\W*[tl]) => 'xhtml1_trans'],
        [qr(xhtml)                        => 'xhtml1'],
    );

    my %doctype_for = (
        default      => q{<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0//EN">},
        html4        => q{<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN">},
        html4_strict => q{<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" } .
                        q{"http://www.w3.org/TR/html4/strict.dtd">},
        html4_loose  => q{<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" } .
                        q{"http://www.w3.org/TR/html4/loose.dtd">},
        xhtml1_1     => q{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" } .
                        q{"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">},
        xhtml1       => q{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML Basic 1.0//EN" } .
                        q{"http://www.w3.org/TR/xhtml-basic/xhtml-basic10.dtd">},
        xhtml1_strict=> q{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" } .
                        q{"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">},
        xhtml1_trans => q{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" } .
                        q{"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">},
    );

    #_check_markup();

    my $doctype = 'default';
    foreach my $d (@doctype_finder) {
        if ($kind =~ m{\A $d->[0]}xmsi) {
            $doctype = $d->[1];
            last;
        }
    }
    $markup->add_raw($doctype_for{$doctype});
}

######################################## MARKUP ACCESS
#
# get all Markup (HTML/XML) as text
#
sub get_markup {
    return $markup ? $markup->as_text() : undef;
}

#
# erase all markup
#
sub clear_markup {
    undef $markup;
    undef $c;
    undef $stash;
    undef $view;
}

#
# clear all (X)HTML so far and create a new markup object
#
sub init_markup {
    my $view_object = shift;
    my $context = shift;
    
    $markup = new Catalyst::View::ByCode::Markup;
    $c = $context;
    $view = $view_object;
    $stash = $context && $context->can('stash')
        ? $context->stash
        : {}; # primitive fallback
}

#
# get reference to markup object
#
sub markup_object {
    return $markup;
}

######################################## HELPERS
#
# a generic handler for HTML Entities
### FIXME: entities do not work right...
#
sub _entity {
    my $entity = shift;
    my ($subname,$wantarray) = (caller(2))[3,5];
    $subname =~ s{\A .* ::}{}xms;

    # warn "entity: $entity - '$subname', w= $wantarray";

    my $char = $entity2char{$entity};
    if (defined($wantarray)) {
        # scalar content - just return code
        return $char;
    }

    # void context - just print
    #_check_markup();
    $markup->add_content($char);
    return;
}

#
# helper: handle tag, apply, fill, with and employ
#
sub _handle_component {
    my $tag = shift;    # tag name (maybe undef if not a tag)
    my $part = shift;   # key to put things into (undef for apply)
    my $code = shift;   # callback to get keys from

    my $element = scalar(@_) && ref($_[-1]) eq 'HASH'
        ? pop()
        : { tag => undef, 
            attr => {}, data => {}, callback => {}, 
            content => [], code => undef };

    if ($tag) {
        #
        # add a tag
        #
        $element->{tag}  = $tag;
        $element->{code} = $code;
    } elsif ($part) {
        #
        # some modifier
        #
        my %things = ( $code->() );
        $element->{$part}->{$_} = $things{$_}
            for keys(%things);
    } else {
        #
        # looks like apply
        #
        $element->{code} = $code;
    }

    return $element if ((caller(1))[5]); # we want an array: let first execute

    # we are first and must execute
    #_check_markup();
    $markup->add_content($element);
}

#
# helper: silently create a markup object if not present
#
sub _check_markup {
    init_markup() if (!$markup);
}

#
# define a function for every tag into a given namespace
#
sub _construct_functions {
    my $namespace  = shift;

    no warnings 'redefine';

    my %declare;
    
    # empty tags like <br>, <hr> ...
    foreach my $tag_name (grep { m{\A \w}xms }
                          keys(%HTML::Tagset::emptyElement)) {
        my $sub_name = $change_tags{$tag_name}
            || $tag_name;

        no strict 'refs';
        *{"$namespace\::$sub_name"} = sub (;&@) {
            my $code = shift; ### testing...
            _handle_component($tag_name, undef, $code, @_);
        };
        $declare{$sub_name} = {
                const => Catalyst::View::ByCode::Declare::tag_parser_for($sub_name)
        };
    }

    # tags with content
    foreach my $tag_name (grep { m{\A \w}xms &&
                                 !exists($HTML::Tagset::emptyElement{$_}) }
                          keys(%HTML::Tagset::isKnown)) {
        my $sub_name = $change_tags{$tag_name}
            || $tag_name;

        no strict 'refs';
        *{"$namespace\::$sub_name"} = sub (;&@) {
            my $code = shift;
            _handle_component($tag_name, undef, $code, @_);
        };
        $declare{$sub_name} = {
            const => Catalyst::View::ByCode::Declare::tag_parser_for($sub_name)
        };
    }
    
    # let Devel::Declare run.
    Devel::Declare->setup_for($namespace, \%declare);
    # Devel::Declare->setup_for($namespace, {
    #     div => {const => Catalyst::View::ByCode::Declare::tag_parser_for(
    #         'div', $namespace, sub (;&@) {
    #             my $code = shift;
    #             _handle_component('div', undef, $code, @_);
    #         }
    #     )}
    # });
    
    # add entities
    foreach my $entity (keys(%entity2char)) {
        no strict 'refs';
        *{"$namespace\::$entity"} = sub { _entity($entity) };
    }
    
}

1;

__END__

=head1 NAME

Catalyst::View::ByCode::Helper - a template engine using the Perl interpreter as its work-horse

=head1 SYNOPSIS

  use Catalyst::View::ByCode::Helper;

  #
  # initialize the markup object
  #
  init_markup();

  #
  # output some unescaped text
  #
  print RAW q{<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0//EN">};

  # this would do almost the same:
  doctype;

  #
  # build a little document
  #
  html {
      head {
          title { 'untitled document' };
      };
      body {
          with {class => 'page-head'} h1 { 'my headline'; };

          #
          # add a form with data automatically put into fields
          #
          using {firstname => 'Howey', gender => 'm'}
          with {method => 'GET'}
          form {

              print OUT 'First Name: ';

              with {name => 'firstname', type => 'text'} input;

              br;

              a { 'click me' } href => 'http://www.yourdomain.com';

              hr;

              print OUT 'Gender: ';
              with {name => 'gender'} choice { # select is a reserved word
                  with {value => 'm'} option { 'male';   };
                  with {value => 'f'} option { 'female'; };
              };
          };
      };
  };

  #
  # generate and print generated markup
  #
  print get_markup();

=head1 DESCRIPTION

C<Catalyst::View::ByCode::Helper> tries to offer an efficient, fast and robust solution
for generating HTML and XHTML markup using standard perl code
encapsulating all nesting into code blocks.

There is no templating language you will have to learn, no quirks with
different syntax rules your editor might not correctly follow and no
indentation problems.

The whole markup is initially constructed as a huge tree-like
structure in memory keeping every reference as long as possible to
allow greatest flexibility and enable deferred construction of every
building block until the markup is actially requested.

Every part of the markup can use almost every type of data with some
reasonable behavior during markup generation.

=head2 USAGE

  use Catalyst::View::ByCode::Helper;
  use Catalyst::View::ByCode::Helper qw(:default);
  use Catalyst::View::ByCode::Helper qw(:markup);
  use Catalyst::View::ByCode::Helper qw(:default :stdout);

By default, C<Catalyst::View::ByCode::Helper> generates a sub for every tag,
that is defined in <HTML::Tagset> except C<select>, C<tr>, C<td>, C<sub> and
C<sup> which are converted to C<choice>, C<trow>, C<tcol>, C<subscript> and
C<superscript>. These subs are imported into the calling namespace and are the
backbone of the markup generation.

If a C<prefix> and/or a C<suffix> parameter is given in the C<use>
statement, no tag-rewriting us used, instead the given names are used
to build the sub names with prefix and/or suffix for you.

If C<stdout> is set to a boolean 'true' value, then STDOUT is changed
in order to redirect simple C<print> statements to generate escaped
markup output like C<print OUT ...> usually does.

=head2 WORKING WITH MARKUP

  init_markup();

By Design, C<Catalyst::View::ByCode::Helper> is a procedural interface to
constructing markup. The markup is a single C<Catalyst::View::ByCode::Markup>
Object that is constucted using the function C<init_markup>. Internally this
markup object saves all generated tags in a memory-kept structure for later
retrieval.

  my $markup_text = get_markup();

This way, the markup may get generated by traversing the memory
structures and expanding all references that reside inside the markup
tree. The result is a pretty-indented HTML or XHTML code.

=head2 POPULATING THE MARKUP

  br;
  br {};
  with {attribute_name => 'attribute_value'} br;
  with {attribute_name => 'attribute_value'} br {};
  br {} with {attribute_name => 'attribute_value'};
  br { attr attribute_name => 'attribute_value' };
  br { attr style => {clear => 'both'} };
  br { id => 'id_identifier' };
  br { class => 'class_name' };
  br { class => [qw(class1 class2 class3)] };
  input { on 'change' => 'some javascript here' };
  input { on 'change' => ['some javascript here', 'more javascript'] };

Empty Tags that do not contain content may get written in all flavors
shown above.

In addition to the tag name attributes may get added to this tag using
the C<with> keyword either in prefix or in suffix notation, even
multiple times or mixed. Alternatively, attributes may be given inside
the code block optionally following an empty tag.

If you prefer an other way, attributes may get defined using the
C<attr> call inside the tag's code block.

The attribute definition by itself must be a list containing key-value
pairs or a hashref. The values of the hashref (or every second entry
of the list) may be:

=over

=item a scalar

A scalar is simply inserted into the attribute value.

=item an array-ref

Every part of the array-ref is inserted into the attribute value
joined together with no separation character.

=item a hash-ref

The key-value pairs of a hash-ref are printed in a shape that is
usable for the C<style> attribute of a tag, dividing the key and the
value by a Colon ':' and separating consecutive pairs by a semicolon
';'. Semicolons, Colons and Dollar signes are escaped as $nnnn
hexadecimal numbers to allow simple hashes to get serialized this
way, so be careful...

=item a sub-ref

Using a subref as an attribute value allows you to defer
value-generation until the markup is actually generated. Depending on
the return value, one (or more) of the rules above are applied.

=back

  div { ...code or markup here... };
  with {...} div { ...code or markup here...};
  div { ...code or markup here...} with {...};
  div { attr name => value, ...; ...code or markup here...};
  using {...} form { ...code or markup here...};
  form { ...code or markup here...} using {...};
  form { data {...}; ...code or markup here...};
  form { data name => value, ...; ...code or markup here...};

Nonempty Tags that contain markup inside are quite similar to empty
tags explained above. The only difference is that empty content forces
the generation of open and close tag pairs
(E<lt>tagE<gt>E<lt>/tagE<gt>) instead of a single tag (E<lt>tag/E<gt>).

Text-like content can be included in various flavors:

  # html-escaped text (result of the last expression inside content)
  div { 'simple text' };

  # using predefined globs
  div { print OUT '<text>'; };   # will also show '&#60;text&#62;'
  div { print RAW '<text>'; };   # will show '<text>' (unescaped)

Additionally, a tag may get data as a hashref or a hash-like list to
use for form population. This only makes sense for the C<form> tag or
course.

As an alternative, you may use this construct:

  set_global_data('id1' => {...whatever...});
  set_global_data('id2' => {...whatever...});
  form { id 'id1'; ... };
  form { id 'id2'; ... };

Here, all data needed for a form is defined at some central point and
during markup-generation a form with an ID that has data defined will
use this data for its fields.

=head2 SOME SHORTCUTS

    load js => '/url/to/file.js';
    load css => '/url/to/file.js';

=head2 CREATING TAG-LIKE THINGS

    #
    # define a tag-like thing
    #
    sub my_own_tag(&;@) {
        #
        # retrieve the code block to call
        #
        my $code = shift;

        #
        # inject our thing into runtime logic
        # allowing 'with' and 'using' constructs
        #
        apply {
            #
            # catch collected things
            # typically: {tag => undef, attr => {}, data => {}}
            #
            my $element = shift;

            #
            # your code comes here, maybe calling the $code somewhere
            # you may forward $element if you like...
            #
            $code->($element);
        };
    }

    # ...

    #
    # use our tag-like thing
    #
    with {name => 'whatever', ...}
    my_own_tag {
        my $element = shift;

        # some markup inside using $element if you like
    };

Hint: using C<data> inside a block you defined this way
will not work. as their usage directly modifies the markup that is
generated. Blocks you define using a sub do not generate a markup
object directly.

=head2 TRICKS USED INSIDE

Everytime, an C<apply> block is called, a hidden empty markup element is
generated. During markup generation this tag can get used to enable some
hidden tricks. These are done with special '-' prefixed attributes. They are
mostly useful in connection with L<Catalyst::View::ByCode::Form> (not yet done).

=over

=item -wrap

wrap a tag around the current element

=item -top

insert the tag as the first content element

=item -bottom

add the tag after the last content element

=item -append

append the tag immediately after the current element

=item -prefix

insert the tag immediately before the current element

=item -trail

use the trail-name as an accumulating id for this tag

=item -group

prepend all 'name' attributes inside this tag by the given name
followed by a period (.).

=item -index

prepend all 'name' attributes inside this tag by the given index
followed by a colon (:).

=item -data

if containing a hashref, the -data attribute is replaced by a series of
data-xxx attributes using the keys appended the 'data-' prefix and the value
as the attribute's value.

=back

=head2 MARKUP SYNTAX AND CAVEATS

When looking at a ready markup, you will very often see things that
are enclosed in curly braces. As you already know, these braces might
denote a code-ref after a sub that has a certain prototype or you
might define a hash-ref literal.

=head1 SEE ALSO

  HTML::BySubs
    this module uses a similar approach using Subs instead of code-refs

  Template::Declare
    again something similar

  HTML::Tagset
    the workhorse in the background supplying all the tag names for us

=head1 BUGS

probably many...

=head1 AUTHOR

Wolfgang Kinkeldei, E<lt>wolfgang@kinkeldei.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Wolfgang Kinkeldei

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut
