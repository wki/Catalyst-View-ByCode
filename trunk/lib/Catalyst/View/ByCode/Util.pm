package Catalyst::View::ByCode::Util;

use strict; 
use warnings;

use base qw(Exporter);
use Exporter;

use UNIVERSAL 'can';
use MIME::Base64;
use YAML;

our @EXPORT = qw(make_hashref
                 clean_path
                 encode_64 decode_64
                 find_sub_in_callers);

our $VERSION = '0.10';

#
# make a hashref from almost anything
#
sub make_hashref {
    my %hash;

    if (ref($_[0]) eq 'HASH') {
        %hash = ( %{ shift() } );
    } elsif (ref($_[0]) eq 'ARRAY') {
        %hash = ( @{ shift() } );
    } else {
        %hash = ( @_ );
    }

    return \%hash;
}


#
# clean a path to a filename into a normalized form
#
sub clean_path {
    my $path = shift;

    $path =~ s{/+}{/}xmsg;         # remove doubles
    $path =~ s{(?<!\A)/\z}{}xmsg;  # remove trailing slash

    return $path;
}

#
# decode the modified base-64 thing
# only containg valid URL characters -- see tr{}{}
# the first 3 chars of a YAML output are always '---' and added
#
sub decode_64 {
    my $encoded = shift;

    $encoded =~ tr{-*}{/=};

    #
    # switch YAML into a safer mode and
    # have same indentation as dumper
    #
    local $YAML::Indent = 1;
    local $YAML::LoadCode = 0;

    return eval { Load('---' . decode_base64($encoded)) };
}

#
# encode into the modified base-64 thing
# only containg valid URL characters -- see tr{}{}
# the first 3 chars of a YAML output are always '---' and stipped off
#
sub encode_64 {
    my $decoded = shift;

    #
    # have same indentation as loader
    #
    local $YAML::Indent = 1;

    my $encoded = encode_base64(Dump($decoded), '');
    $encoded =~ tr{/=}{-*};

    return substr($encoded,4); # strip off first 4 (decoded '---') chars
}

#
# find a named sub in caller's namespace
#
sub find_sub_in_callers {
    my $sub_name = shift;

    return if (!$sub_name || ref($sub_name));

    #
    # first try: find out if sub is exported in any component so far
    # if HTML::ByCode::Context is already in use somewhere
    #
    no strict 'refs';
    if (my $context = ${"HTML::ByCode::Context::current_context"}) {
        #
        # HTML::ByCode::Context is already in use - query it!
        #
        if ($context->can($sub_name)) {
            return $context->get_sub($sub_name);
        }
    }
    use strict 'refs';

    #
    # TODO: do we still need this?
    # second try: take from defined constant in caller-stack if possible
    #
    my $level = 0;
    my $caller_package;
    do {
        $caller_package = caller($level);
        if ($caller_package && can($caller_package,$sub_name)) {
            #
            # requested constant was found
            #
            no strict 'refs';
            return \&{"$caller_package\::$sub_name"};
        }
        $level++; # avoid endless loop see below.
    } while ($caller_package && $level < 100);

    #
    # nothing found
    #
    return;
}

1;

__END__

=head1 NAME

Catalyst::View::ByCode::Util - misc utility functions usable elsewhere

=head1 SYNOPSIS

   use Catalyst::View::ByCode::Util;

=head1 DESCRIPTION

Stub documentation for Catalyst::View::ByCode::Util,
Blah blah blah.

=head2 EXPORT

clean_path

encode_64

decode_64

find_sub_in_callers

=head1 SEE ALSO

=head1 BUGS

=head1 AUTHOR

Wolfgang Kinkeldei, E<lt>wolfgang@kinkeldei.de<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Wolfgang Kinkeldei

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
