package Catalyst::View::ByCode::Template;

use strict;
use warnings;

use vars qw(*__ENTRY);

our $VERSION = '0.10';

######################################## BUILDER
#
# constructor - build a new template based on a path to a file
#
# call with: new Catalyst::View::ByCode::Component($c, '/path/of/component');
#
sub new {
    my $class = shift;
    my $c     = shift;
    my $path  = shift;

    my $self;
    if (exists($components{$path})) {
        #
        # already existing -- use known version
        #
        $self = $components{$path};
    } else {
        #
        # new component - build from scratch
        #
        $self = bless {}, $class;

        $self->{last_modified} = 0;         # last modification time
        $self->{path}          = $path;     # absolute path in filesystem
        $self->{need_compile}  = 1;         # cleared upon success
        $self->{is_runnable}   = 0;         # not unless compiled
        $self->{attributes}    = {};        # ATTRibutes for subs
        $self->{import_from}   = [];        # components to import from
        $self->{use_modules}   = [];        # list of modules to use
        $self->{sub}           = {};        # exportable subs

        #
        # cache for later reuse
        #
        $components{$path} = $self;
    }

    #
    # init possibly overriden args
    #
    $self->{run_subname}  = $RUN_SUBNAME;
    $self->{wrap_subname} = $WRAP_SUBNAME;

    #
    # append args
    #
    $self->{$_} = $args{$_}
        for keys(%args);
    $self->{filename} = substr($path, length($self->{document_root}||''));

    #
    # update some flags
    #
    $self->{did_compile} = 0; # reset 'just compiled' flag
    if ($self->{path} && -f $self->{path}) {
        #
        # file is present
        #
        $self->{can_compile} = 1;
        my $mtime = (stat($self->{path}))[9];
        if ($self->{last_modified} != $mtime) {
            #
            # file changed -- mark for recompile
            #
            $self->{need_compile}  = 1;
            $self->{last_modified} = $mtime;
            $self->{is_runnable}   = 0;
        }
    } else {
        #
        # file not present
        #
        $self->{can_compile}   = 0;
        $self->{last_modified} = 0; # just a unlike value
        $self->{is_runnable}   = 0;

        HTML::ByCode::NoTemplateError->throw(
            component => $self->{filename},
            error     => "file not found for compilation '$self->{filename}'",
        );
    }

    #
    # compile if needed -- throw exception upon failure
    #
    $self->{_coderefs} = {}; # cache for CODE-ATTR stuff
    $self->{_imported} = {}; # list of imported subs
    $self->compile() if ($self->{need_compile} && $self->{can_compile});

    #
    # done.
    #
    return $self;
}

#
# prepare for running
#
sub prepare {
    my $self = shift;

    #
    # build ties to storages if needed
    #
    storage_prepare($self->{package});
}

#
# cleanup things that should not survive during several instantiations
#
sub cleanup {
    my $self = shift;

    #
    # untie storages
    #
    storage_cleanup($self->{package});
}

######################################## OBJECT STATUS ACCESS
#
# some getters
#
sub did_compile { return shift->{did_compile}; } # just compiled flag
sub can_compile { return shift->{can_compile}; } # if file exists
sub is_runnable { return shift->{is_runnable}; } # if successfully compiled

#
# convenience replacement for UNIVERSAL::can
# used to test the compiled function's subs for existence
# usage: $component->can('subname')
#
sub can { return UNIVERSAL::can($_[0]->{package},$_[1]); }

######################################## COMPILING
#
# compile a component into a package
# Throws: 'NoComponentError' or 'CompileEror'
#
sub compile {
    my $self = shift;

    my $start_time  = [gettimeofday];
    my $filename = $self->{filename};

    #
    # mark this as currently compiling (accept attribute definition)
    #
    local $compiling_component = $self;

    #
    # reset flags for allowing direct compile request
    #
    $self->{is_runnable} = 0;  # not runnable unless compiled
    $self->{did_compile} = 0;  # not yet finished
    $self->{attributes}  = {}; # no attributes (yet)
    $self->{sub}         = {}; # no subs yet to export

    #
    # find out package name if not yet assigned
    #
    $self->{package} ||= 'HTML::ByCode::Component::_TPL' . $component_nr++;

    #
    # clear target package's namespace before we start
    #
    no strict 'refs';
    %{*{"$self->{package}\::"}} = ();
    use strict 'refs';

    #
    # slurp in the file
    #
    my $file_contents;
    if (open(my $file, '<', $self->{path})) {
        local $/ = undef;
        $file_contents = <$file>;
        close($file);
    } else {
        HTML::ByCode::NoComponentError->throw(
            component => $self->{filename},
            error     => "component file '$filename' not readable",
        );
    }

    #
    # deep-copy all attributes from imported packages to $self->{attributes}
    # import all subs into destination namespace
    #
    foreach my $import_component (@{$self->{import_from}}) {
        # copy attributes
        $self->{attributes}->{$_} = { %{$import_component->{attributes}->{$_}} }
            for keys(%{$import_component->{attributes}});

        # transfer all exported subs from lower levels
        no strict 'refs';
        *{"$self->{package}\::$_"} = $import_component->{sub}->{$_}
            for keys(%{$import_component->{sub}});
    }

    #
    # build some magic code around the template's code
    #
    my $package      = __PACKAGE__;
    my $use_modules  = join("\n",
                            map {"use $_;"}
                            @{$self->{use_modules}});
    my $storage_vars = join("\n",
                            map {"our \%$_;"}
                            storage_vars());

    my $code = <<__EOCODE__;
# auto-generated code - do not modify
# generated by Catalyst::View::ByCode::Component
# original filename: $filename

package $self->{package};
use strict;
use warnings;

use base qw($package);

use Catalyst::View::ByCode qw(:default);
use HTML::ByCode::Context;
use HTML::ByCode::Interpolation;
$use_modules
use $package; # must be the last one -- see import()

# add storage area vars -- tying is done in prepare()
$storage_vars

# subs that are overloaded here would warn otherwise
no warnings 'redefine';
__EOCODE__

    ;
    # count lines created so far (@lines added to avoid warnings)
    my $header_lines = scalar(my @lines = split(/\n/, $code));

    # create magic sub 'RUN' unless defined in source
    if ($file_contents =~ m{\b sub \s+ $RUN_SUBNAME \s* \{}xms) {
        # sub is defined in source -- no sub around file
        $code .= "$file_contents\n";
    } else {
        # create a sub around our file
        $code .= "sub $RUN_SUBNAME { $file_contents }\n";
    }

    $code .= "\n1;\n";

    if (0) {
        ## debugging only -> save generated code
        if (open(my $out, '>', "$self->{path}__OUT.pl")) {
            print $out $code;
            close($out);
        }
    }

    #
    # compile that
    #
    eval $code;
    if ($@) {
        #
        # ensure we will recompile
        #
        $self->{last_modified} = 0;
        
        #
        # throw error
        #
        my $msg = $@;
        $msg =~ s{at\s\(eval\s+\d+\)\s+line\s+(\d+)}{"at '$filename' line " . ($1 - $header_lines)}exmsg;
        HTML::ByCode::CompileError->throw(
            component => $self->{filename},
            error     => "component file '$filename' not compilable: $msg"
        );
    }

    #
    # create some magic _variables
    #
    no strict 'refs';
    ${"$self->{package}\::_filename"} = $filename;
    ${"$self->{package}\::_offset"} = $header_lines;
    use strict 'refs';

    #
    # rework all saved references of CODE-ATTR subs
    #
    foreach my $sub_attrs (values(%{$self->{_coderefs}})) {
        my $sub_ref  = $sub_attrs->[0]->{ref};
        my $sub_name = _find_sym($self->{package}, $sub_ref);
        if ($sub_name) {
            #
            # we found it - process all ATTRs
            #
            foreach my $attr (@{$sub_attrs}) {
                my $attr_name = $attr->{attr_name};
                my $attr_args = $attr->{attr_args};

                $self->{attributes}->{$sub_name}->{$attr_name} = $attr_args;

                #
                # decide if we have to make something exportable
                #
                if ($attr_name ne 'private') {
                    $self->_make_exportable($sub_name);
                }
            }
        } else {
            # not found -- should not happen, we currently compile it...
            warn "Symbol not found: $self->{package} --> $sub_ref";
        }
    }

    #
    # make all remaining subs without any ATTR exportable
    # ( ATTR ':protected' is default)
    #
    $self->_make_exportable($_)
        for grep {!exists($self->{_imported}->{$_}) &&
                  !exists($self->{attributes}->{$_})}
            _all_subs($self->{package});

    #
    # update component info
    #
    $self->{need_compile} = 0;  # code above was successful
    $self->{is_runnable}  = 1;  # successful compile
    $self->{did_compile}  = 1;  # we just did...
    $self->{_coderefs}    = {}; # not needed until next compile...
    $self->{_imported}    = {}; # not needed until next compile...

    logger->info("compilation of '$filename', time elapsed: " .
                     tv_interval($start_time, [gettimeofday]));

    #
    # done
    #
    return;
}

#
# internal helper: make a symbol exportable by saving it into $self->{sub}
#
sub _make_exportable {
    my $self   = shift;
    my $symbol = shift;

    no strict 'refs';
    $self->{sub}->{$symbol} = \&{"$self->{package}\::$symbol"};
}

#
# internal helper: find a symbol name for a coderef
#                  coderefs are entered _after_ compiling a sub
#                  therefore processing ATTRs has been deferred
#
sub _find_sym {
    my ($package, $ref) = @_;

    my $type = ref($ref); # 'CODE', 'HASH', ...

    no strict 'refs';
    for (values %{"$package\::"}) {
        if (*{$_}{$type} && *{$_}{$type} == $ref) {
            # copy to a local variable to avoid
            # manipulating the loop's value...
            my $name = "$_";
            $name =~ s{\A .* ::}{}xms;
            return $name;
        }
    }

    return;
}

#
# internal helper: list all subs of a given package
#
sub _all_subs {
    my $package = shift;

    my @subs;

    no strict 'refs';
    while (my ($key,$val) = each (%{*{"$package\::"}})) {
        local (*__ENTRY) = $val;
        push @subs, $key
            if ($key =~ m{\A[a-z]}xms
                && defined(*__ENTRY{CODE}));
    }
    use strict 'refs';

    return @subs;
}

1;

__END__

=head1 NAME

HTML::ByCode::Component - a helper class for HTML::ByCode::ModPerlHandler

=head1 VERSION

Version 0.10

=head1 SYNOPSIS

  use HTML::ByCode::Component;

  #
  # set global things if you like
  #
  $HTML::ByCode::Component::RUN_SUBNAME = 'subname_you_like';

  #
  # create a new Component
  # (setting things per component)
  #
  my $component = new HTML::ByCode::Component('/path/of/component.ext',
                                              run_subname   => 'subname',
                                              import_from   => [...],
                                              use_modules   => [...]);


=head1 SEE ALSO

  HTML::ByCode::ModPerlHandler
    a handler for Apache running modPerl using HTML::ByCode

  HTML::ByCode::Context
    an execution environment used by HTML::ByCode::ModPerlHandler

=head1 BUGS

probably many...

=head1 AUTHOR

Wolfgang Kinkeldei, E<lt>wolfgang@kinkeldei.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Wolfgang Kinkeldei

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut
