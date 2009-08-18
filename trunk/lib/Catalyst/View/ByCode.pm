package Catalyst::View::ByCode;

use Moose;
extends 'Catalyst::View';

has extension => (is => 'rw', default => '.pl');
has root_dir  => (is => 'rw', default => 'root/bycode');
has wrapper   => (is => 'rw', default => 'wrapper.pl');
has include   => (is => 'rw', default => sub { [] });

# Config Options:
#    root_dir => 'bycode',
#    extension => '.pl',
#    wrapper => 'wrapper.pl', # will be overridden by stash{wrapper}
#    include => [...] -- packages to use in every template
#
# Stash Variables:
#    template => 'path/to/template'
#    yield => { name => 'path/to/yield' }
#    yield_list => [ wrapper, template ]
#    wrapper => 'path/to/wrapper'
#
#    set by Catalyst (we need them!):
#      - current_view 
#      - current_view_instance
#
#

use Catalyst::View::ByCode::Renderer qw(:markup);
use Catalyst::Utils;
use UUID::Random;
use Path::Class::File;
use File::Spec;

our $VERSION = '0.04';

=head1 NAME

Catalyst::View::ByCode - Templating using pure Perl code

=head1 SYNOPSIS

    # 1) use the helper to create your View
    myapp_create.pl view ByCode ByCode


    # 2) inside your Controllers do business as usual:
    sub index :Path :Args(0) {
        my ($self, $c) = @_;
        
        # unless defined as default_view in your config, specify:
        $c->stash->{current_view} = 'ByCode';
        
        $c->stash->{title} = 'Hello ByCode';
        
        # if omitted, would default to 
        # controller_namespace / action_namespace .pl
        $c->stash->{template} = 'hello.pl';
    }


    # 3) create a simple template eg 'root/bycode/hello.pl
    # REMARK: 
    #    use 'c' instead of '$c'
    #    prefer 'stash->{...}' to 'c->stash->{...}'
    template {
        html {
            head {
                title { c->stash->{title} };
                load Js => 'site.js';
                load Css => 'site.js';
            };
            body {
                div header.noprint {
                    ul.topnav {
                        li {'home'};
                        li {'surprise'};
                    };
                };
                div content {
                    h1 { c->stash->{title} };
                    div { 'hello.pl is running! };
                    img(src => '/static/images/catalyst_logo.png');
                };
            };
        };
    }
    # 278 characters without white space
    
    
    # 4) expect to get this HTML generated:
    <html>
      <head>
        <title>Hello ByCode!</title>
        <script src="http://localhost:3000/js/site.js" type="text/javascript">
        </script>
        <link rel="stylesheet" href="http://localhost:3000/css/site.css" type="text/css" />
      </head>
      <body>
        <div id="header" style="noprint">
          <ul class="topnav">
            <li>home</li>
            <li>surprise</li>
          </ul>
        </div>
        <div class="content">
          <h1>Hello ByCode!</h1>
          <div>hello.pl is running!</div>
          <img src="/static/images/catalyst_logo.png" />
        </div>
      </body>
    </html>
    # 453 characters without white space

=head1 DESCRIPTION

C<Catalyst::View::ByCode> tries to offer an efficient, fast and robust
solution for generating HTML and XHTML markup using standard perl code
encapsulating all nesting into code blocks.

Instead of typing opening and closing HTML-Tags we simply call a
sub named like the tag we want to generate:

    div { 'hello' }
    
generates:

    <div>hello</div>

There is no templating language you will have to learn, no quirks with
different syntax rules your editor might not correctly follow and no
indentation problems.

The whole markup is initially constructed as a huge tree-like
structure in memory keeping every reference as long as possible to
allow greatest flexibility and enable deferred construction of every
building block until the markup is actially requested.

Every part of the markup can use almost every type of data with some
reasonable behavior during markup generation.

=head2 Tags

Every tag known in HTML (or defined in L<HTML::Tagset> to be precise) gets
exported to a template's namespace during its compilation and can be used as
expected. However, there are some exceptions which would collide with CORE
subs or operators

=over 12

=item choice

generates a E<lt>selectE<gt> tag

=item link_tag

generates a E<lt>linkE<gt> tag

=item trow

generates a E<lt>trE<gt> tag

=item tcol

generates a E<lt>tdE<gt> tag

=item subscript

generates a E<lt>subE<gt> tag

=item superscript

generates a E<lt>supE<gt> tag

=item meta_tag

generates a E<lt>metaE<gt> tag

=item quote

generates a E<lt>qE<gt> tag

=item strike

generates a E<lt>s<gt> tag

=item map_tag

generates a E<lt>mapE<gt> tag

=back

Internally, every tag subroutine is defined with a prototype like

    sub div(;&@) { ... }

Thus, the first argument of this sub is expected to be a coderef, which allows
to write code like the examples above. Nesting tags is just a matter of
nesting calls into blocks.

=head2 Content

There are several ways to generate content which is inserted between the
opening and the closing tag:

=over

=item

The return value of the last expression of a code block will get appended to
the content inside the tag. The content will get escaped when needed.

=item

To append any content (getting escaped) at any point of the markup generation,
the C<OUT> glob can be used:

    print OUT 'some content here.';

=item

To append unescaped content eg JavaScript or the content of another
markup-generating subsystem like C<HTML::FormFu> simple use the <RAW> glob:

    print RAW '<?xxx must be here for internal reasons ?>';

=back

=head2 Attributes

As usual for Perl, there is always more than one way to do it:

=over

=item old-school perl

    # appending attributes after tag
    div { ... content ... } id => 'the_id', class => 'some_class';
    
=item special content

    # using special methods
    div {
        id 'top';
        class 'noprint silver';
        attr style => 'display: none';
        
        'content'
    };

=item tricky arguments

    div top.noprint.silver(style => 'display none') {'content'}

=back

=head2 Special Methods

=over

=item doctype

=item load

=back

=head2 Building Reusable blocks

You might build a reusable block line the following calls:

    block 'block_name' => sub { ... };
    
    # or shorter:
    block block_name { ... };

The block might get used like a tag:

    block_name { ... some content ... };

If a block-call contains a content it can get rendered inside the block using
the special sub C<block_content>. A simple example makes this clearer:

    # define a block:
    block infobox {
        my $headline = attr('headline') || 'untitled';
        div.infobox {
            div.head { $headline };
            div.info { block_content };
        };
    };
    
    # later we use the block:
    infobox(headline => 'Our Info') { 'just my 2 cents' };
    
    # this HTML will get generated:
    <div class="infobox">
      <div class="head">Our Info</div>
      <div class="info">just my 2 cents</div>
    </div>

=head1 CONFIGURATION

A simple configuration of a derived Controller could look like this:

    __PACKAGE__->config(
        # Change extension (default: .pl)
        extension => '.pl',
        
        # Set the location for .pl files (default: root/bycode)
        root_dir => cat_app->path_to( 'root', 'bycode' ),
        
        # This is your wrapper template located in root_dir (default: wrapper.pl)
        wrapper => 'wrapper.pl',
    );

=head1 METHODS

=cut

sub BUILD {
    my $self = shift;
    
    #my $c = $self->_app;
    if (exists($self->config->{extension})) {
        $self->extension($self->config->{extension});
    }
    if (exists($self->config->{root_dir})) {
        $self->root_dir($self->config->{root_dir});
    }
    #$c->log->warn("directory '" . $self->root_dir . "' not present.")
    #    if (!-d $c->path_to('root', $self->root_dir));
    if (exists($self->config->{wrapper})) {
        $self->wrapper($self->config->{wrapper});
    }
}

#
# intercept dies and correct
#  - file-name to template
#  - line-number by subtracting top-added part
#
sub _handle_die {
    my $msg = shift;
    die $msg if (ref($msg)); # exceptions will forward...
    
    my $package = caller();
    my ($start, $file, $line) = ($msg =~ m{\A (.+ \s at) \s (/.+)\s+ line \s+ (\d+) \.? \s* \z}xmsg);
    
    no strict 'refs';
    if ($file && ${"$package\::_tempfile"} && $file eq ${"$package\::_tempfile"}) {
        $line -= ${"$package\::_offset"};
        my $template = $package;
        $template =~ s{\A .+ :: Template}{}xms;
        $template =~ s{::}{/}xmsg;
        
        $msg = "$start Template:$template line $line.\n";
    }
    
    die $msg;
}

#
# intercept warns and correct
#  - file-name to template
#  - line-number by subtracting top-added part
#
# then log then using Catalyst's logging facility
#
# will be called by a curried sub... -- see below
#
sub _handle_warn {
    my $logger = shift;
    my $msg = shift;
    
    my $package = caller(1);
    my ($start, $file, $line) = ($msg =~ m{\A (.+ \s at) \s (/.+)\s+ line \s+ (\d+) \.? \s* \z}xmsg);
    
    no strict 'refs';
    if ($file && ${"$package\::_tempfile"} && $file eq ${"$package\::_tempfile"}) {
        $line -= ${"$package\::_offset"};
        my $template = $package;
        $template =~ s{\A .+ :: Template}{}xms;
        $template =~ s{::}{/}xmsg;
        
        $msg = "$start Template:$template line $line.\n";
    }
    
    $logger->warn($msg);
}

=head2 process

fulfill the request (called from Catalyst)

=cut

sub process {
    my $self = shift;
    my $c = shift;
    
    #
    # must render - find template and wrapper
    #
    my @yield_list = ();
    
    my $template = $c->stash->{template}
        ||  $c->action . $self->extension;
    if (!defined $template) {
        $c->log->error('No template specified for rendering');
        return 0;
    } else {
        my $path = $self->_find_template($c, $template);
        my $sub;
        if ($path && ($sub = $self->_compile_template($c, $path))) {
            $c->log->debug("FOUND template '$template' -> '$path'") if $c->debug;
            push @yield_list, $sub;
        } else {
            $c->log->error("requested template '$template' not found or not compilable");
            return 0;
        }
    }

    my $wrapper = exists($c->stash->{wrapper})
        ? $c->stash->{wrapper}
        : $self->wrapper;
    if ($wrapper) {
        my $path = $self->_find_template($c, $wrapper, $template); ### FIXME: must chop off last part from $template
        my $sub;
        if ($path && ($sub = $self->_compile_template($c, $path))) {
            unshift @yield_list, $sub;
        } else {
            $c->log->error("wrapper '$wrapper' not found or not compilable");
        }
    } else {
        $c->log->info('no wrapper wanted') if $c->debug;
    }

    #
    # run render-sequence
    #
    $c->stash->{yield} ||= {};
    $c->stash->{yield_list} = \@yield_list;
    init_markup($self, $c);
    {
        #
        # beautify dies by replacing our strange file names
        # with the relative path of the wrapper
        #
        local $SIG{__DIE__} = \&_handle_die;
        local $SIG{__WARN__} = sub { _handle_warn($c->log, @_) };
        
        #
        # let automatism work thru the yield-list
        #
        Catalyst::View::ByCode::Renderer::yield;
    };
    my $output = get_markup();
    clear_markup;
    
    $c->response->body($output);
    
    return 1; # indicate success
}

# DEAD CODE
# =head2 render
# 
# render the request
# 
# =cut
# 
# sub render {
#     my $self = shift;
#     my $c = shift;
#     my $template = shift;
#     my $args = shift;
#     
#     $c->log->debug("Rendering template '$template'") if $c->debug;
#     
#     my $sub = $self->_compile_template($c,$template);
#     
#     $sub->($c) if ($sub);
# }

#
# convert a template filename to a package name
#
sub _template_to_package {
    my $self = shift;
    my $c = shift;
    my $template = shift;  # relative path
    
    $template =~ s{\.\w+\z}{}xms;
    $template =~ s{/+}{::}xmsg;
    
    my $package_prefix = Catalyst::Utils::class2appclass($self);
    my $package = "$package_prefix\::Template\::$template";
    
    return $package;
}

#
# helper: find a given template
#     returns: relative path to template (including extension)
#
# FIXME: is it wise to always climb up the directory? Think!
#
sub _find_template {
    my $self = shift;
    my $c = shift;
    my $template = shift;  # relative path
    my $start_dir = shift || '';
    
    my $root_dir = $c->path_to($self->root_dir);
    my $ext = $self->extension;
    $ext =~ s{\A \.+}{}xms;
    my $count = 100; # prevent endless loops in case of logic errors
    while (--$count > 0) {
        if (-f "$root_dir/$start_dir/$template") {
            # we found it
            return $start_dir ? "$start_dir/$template" : $template;
        } elsif (-f "$root_dir/$start_dir/$template.$ext") {
            # we found it after appending extension
            return $start_dir ? "$start_dir/$template.$ext" : "$template.$ext";
        }
        last if (!$start_dir);
        $start_dir =~ s{/*[^/]*/*\z}{}xms;
    };
    
    #
    # no success
    #
    return;
}

#
# helper: find and compile a template
#
sub _compile_template {
    my $self = shift;
    my $c = shift;
    my $template = shift;
    my $sub_name = shift || 'RUN';
    
    return 42 if (!$template);
    $c->log->debug("compiling: $template") if $c->debug;
    
    #
    # convert between path and package
    #
    my $template_path;
    my $template_package;
    if ($template =~ m{::}xms) {
        #
        # this is a package name
        #
        $template_package = $template;
        $template_path = $template;
        $template_path =~ s{::}{/}xmsg;
    } else {
        #
        # this is a path
        #
        $template_path = $template;
        $template_package = $template;
        $template_package =~ s{/}{::}xmsg;
        $template_package =~ s{\.\w+\z}{}xms;
    }
    # $template_path = $self->root_dir . "/$template_path";

    #
    # see if we know the package
    #
    #my $package_prefix = Catalyst::Utils::class2appclass($self);
    #my $package = "$package_prefix\::Template::$template_package";
    my $package = $self->_template_to_package($c, $template_path);

    no strict 'refs';
    my $full_path = ${"$package\::_filename"};
    my $package_mtime = ${"$package\::_mtime"};
    my $file_mtime = $full_path && -f $full_path
        ? (stat $full_path)[9]
        : 0;
    use strict 'refs';
    
    if (!$full_path || !$file_mtime) {
        # we don't know the template or it has vanished somehow
        my $full_path = $c->path_to($self->root_dir, $template_path);
        if (-f $full_path) {
            # found!
            # $c->log->debug(qq/found template "$template_path"/) if $c->debug;
            $self->__compile($c, "$full_path" => $package);
        }
    } elsif ($file_mtime != $package_mtime) {
        # we need a recompile
        $self->__compile($c, $full_path => $package);
    }
    
    $c->log->debug('can run: ', $package->can($sub_name)) if $c->debug;
    
    return $package->can($sub_name);
}

# low level compile
sub __compile {
    my $self = shift;
    my $c = shift;
    my $path = shift;
    my $package = shift;

    $c->log->debug("compile template :: $path --> $package") if $c->debug;
    
    #
    # clear target package's namespace before we start
    #
    no strict 'refs';
    %{*{"$package\::"}} = ();
    use strict 'refs';

    #
    # slurp in the file
    #
    my $file_contents;
    if (open(my $file, '<', $path)) {
        local $/ = undef;
        $file_contents = <$file>;
        close($file);
    } else {
        $c->log->error('Error opening file');
        return; ### FIXME: throw exception is better
    }

    #
    # build some magic code around the template's code
    #
    my $include = join("\n", map {"use $_;"} @{$self->include});
    my $now = localtime(time);
    my $mtime = (stat($path))[9];
    my $code = <<PERL;
# auto-generated code - do not modify
# generated by Catalyst::View::ByCode at $now
# original filename: $path

package $package;
use strict;
use warnings;
use utf8;

use Devel::Declare();
use Catalyst::View::ByCode::Renderer qw(:default);
$include
# subs that are overloaded here would warn otherwise
no warnings 'redefine';
PERL

    # count lines created so far (@lines added to avoid warnings)
    my $header_lines = scalar(my @lines = split(/\n/, $code));

    $code .= "\n$file_contents;\n\n1;\n";
    
    #
    # Devel::Declare does not work well with eval()'ed code...
    #                thus, we need to save into a TEMP-file
    #
    my $tempfile = Path::Class::File->new(File::Spec->tmpdir,
                                          UUID::Random::generate . '.pl');
    $c->log->debug("tempfile = $tempfile") if $c->debug;
    open(my $tmp, '>', $tempfile);
    print $tmp $code;
    close($tmp);
    
    #
    # create some magic _variables
    #
    no strict 'refs';
    ${"$package\::_filename"} = $path;
    ${"$package\::_offset"}   = $header_lines;
    ${"$package\::_mtime"}    = $mtime;
    ${"$package\::_tempfile"} = "$tempfile";
    use strict 'refs';

    #
    # compile that
    #
    do $tempfile;
    unlink $tempfile;
    if ($@) {
        #
        # error during compile
        #
        $c->log->error(qq/compile error: $@/);
        return; ### FIXME: throwing an error is better
    }
    $c->log->debug('compiling done') if $c->debug;
    
    #
    # done
    #
    return 1;

}

=head1 AUTHOR

Wolfgang Kinkeldei, E<lt>wolfgang@kinkeldei.deE<gt>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
