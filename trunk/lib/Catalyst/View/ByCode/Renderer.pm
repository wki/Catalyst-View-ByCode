package Catalyst::View::ByCode::Renderer; ## replacement for Helper
use strict;
use warnings;
use base qw(Exporter);

use Devel::Declare();
#use Catalyst::View::ByCode::Util;
use Catalyst::View::ByCode::Declare;
use Catalyst::View::ByCode::Markup::Document;
use HTML::Tagset;

our @EXPORT_OK  = qw(clear_markup init_markup get_markup markup_object);

our @EXPORT     = qw(doctype
                     load
                     yield
                     attr
                     apply
                     class id on
                     stash c _);
our %EXPORT_TAGS = (
    markup  => [qw(clear_markup init_markup get_markup markup_object)],
    default => [@EXPORT, @EXPORT_OK],
);

#
# define variables
#
our $document; # initialized with 'init_markup',  ### FIXME: right?
             # doing this during 'import' could be bad
our $stash;  # current stash
our $c;      # current context
our $view;   # ByCode View instance

#
# some tags get changed by simply renaming them
#
our %change_tags = ('select' => 'choice',
                    'link'   => 'link_tag',
                    'tr'     => 'trow',
                    'td'     => 'tcol',
                    'sub'    => 'subscript',
                    'sup'    => 'superscript',
                    'meta'   => 'meta_info',    # Moose needs &meta()...
);

######################################## IMPORT
#
# just importing this module...
#
sub import {
    my $module = shift; # eat off 'Catalyst::View::ByCode::Renderer';

    my $calling_package = caller;

    my $default_export = grep {$_ eq ':default'} @_;

    # warn "bycode: default_export = $default_export, caller=$calling_package";

    #
    # build HTML Tag-subs into caller's namespace
    #
    _construct_functions($calling_package)
        if ($default_export);

    #
    # do Exporter's Job on Catalyst::View::ByCode::Renderer's @EXPORT
    #
    $module->export_to_level(1, $module, @_);

    #
    # create *OUT and *RAW in calling package to allow 'print' to work
    #   'print OUT' works, Components use a 'select OUT' to allow 'print' alone
    #
    no strict 'refs';
    if ($default_export || !scalar(@_)) {
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
    my $class  = shift; # my class (Catalyst::View::ByCode::Renderer)
    my $handle = shift; # escaping on or off -- use this value as handle
                        # and its value to decide escaping
                        # -- see PRINT/PRINTF below

    return bless \$handle, $class;
}

sub PRINT {
    my $handle = shift;
    $document->add_text(join('', @_), $$handle == 0);
}

sub PRINTF {
    my $handle = shift;
    $document->add_text(sprintf(@_), $$handle == 0);
}

######################################## MARKUP
#
#
#
sub clear_markup {
    # $document->DESTROY(); ### still needed? playing nicely with Moose?
    undef $document;
    undef $c;
    undef $stash;
    undef $view;
}

sub init_markup {
    my $view_object = shift;
    my $context = shift;
    
    $document = new Catalyst::View::ByCode::Markup::Document;
    $c = $context;
    $view = $view_object;
    $stash = $context && $context->can('stash')
        ? $context->stash
        : {}; # primitive fallback
}

sub get_markup {
    return $document ? $document->as_text : '';
}

sub markup_object {
    return $document;
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
            $document->add_tag(link => {
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
            $document->add_tag(script => {
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
        
        if ($kind eq 'Css') {
            $document->add_tag(link => {
                    rel  => 'stylesheet',
                    type => 'text/css',
                    href => sub {
                        $c->uri_for($controller->action_for('default'), @_);
                    },
            });
        } else {
            $document->add_tag(script => {
                    type => 'text/javascript',
                    src  => sub {
                        $c->uri_for($controller->action_for('default'), @_);
                    },
            });
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

    $sub->(@_) if ($sub && ref($sub) eq 'CODE');

    return;
}

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
### FIXME: does not work now.   
sub apply(&;@) { # _handle_component(undef, undef, @_); 
}

#
# set attribute(s) of latest open tag (instead of 'with' outside)
#
sub attr { $document->set_attr(@_); return; }

#
# set a class inside a tag
#
sub class { $document->set_attr(class => join(' ', @_)); return; }

#
# set an ID
#
sub id { $document->set_attr(id => $_[0]); return; }

#
# define a javascript-handler
#
sub on {
    my $handler = shift;

    $document->set_attr("on$handler" => join('', @_));
    return;
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
    
    my $doctype = 'default';
    foreach my $d (@doctype_finder) {
        if ($kind =~ m{\A $d->[0]}xmsi) {
            $doctype = $d->[1];
            last;
        }
    }
    
    $document->add_text($doctype_for{$doctype}, 1);
}

######################################## Locale stuff
#
# get a localized version of something
#
sub _ {
    return $c->localize(@_);
}

# eliminated: sub _handle_component {}
sub _handle_tag {
    my $tag_name = shift;
    my $code = shift;
    
    $document->open_tag($tag_name);
    $document->add_text($code->(@_)) if ($code);
    $document->close_tag($tag_name);
}

#
# define a function for every tag into a given namespace
#
sub _construct_functions {
    my $namespace  = shift;

    no warnings 'redefine';

    my %declare;

    # tags with content are treated the same as tags without content
    foreach my $tag_name (grep { m{\A \w}xms }
                          keys(%HTML::Tagset::isKnown)) {
        my $sub_name = $change_tags{$tag_name}
            || $tag_name;

        # install a tag-named sub in caller's namespace
        no strict 'refs';
        *{"$namespace\::$sub_name"} = sub (;&@) {
            _handle_tag($tag_name, @_);
        };
        use strict 'refs';
        
        # remember me to generate a magic tag-parser that applies extra magic
        $declare{$sub_name} = {
            const => Catalyst::View::ByCode::Declare::tag_parser
        };
    }
    
    # install all tag-parsers collected above
    Devel::Declare->setup_for($namespace, \%declare);
    
    # # add entities
    # foreach my $entity (keys(%entity2char)) {
    #     no strict 'refs';
    #     *{"$namespace\::$entity"} = sub { _entity($entity) };
    # }
    
}

1;
