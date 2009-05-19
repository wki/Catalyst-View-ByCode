package Catalyst::Helper::View::ByCode;

use strict;

=head1 NAME

Catalyst::Helper::View::ByCode - Helper for ByCode Views

=head1 SYNOPSIS

    script/create.pl view ByCode ByCode

=head1 DESCRIPTION

Helper for ByCode Views.

=head2 METHODS

=head3 mk_compclass

=cut

sub mk_compclass {
    my ( $self, $helper ) = @_;
    my $file = $helper->{file};
    $helper->render_file( 'compclass', $file );
}

=head1 SEE ALSO

L<Catalyst::Manual>, L<Catalyst::Helper>

=head1 AUTHOR

Wolfgang Kinkeldei, E<lt>wolfgang@kinkeldei.deE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as perl itself.

=cut

1;

__DATA__

__compclass__
package [% class %];

use strict;
use warnings;
use parent 'Catalyst::View::ByCode';

__PACKAGE__->config(
    # # Change default
    # extension => '.pl',
    # 
    # # Set the location for .pl files
    # root_dir => cat_app->path_to( 'root', 'bycode' ),
    # 
    # # This is your wrapper template located in the 'root/src'
    # wrapper => 'wrapper.pl',
);

=head1 NAME

[% class %] - ByCode View for [% app %]

=head1 DESCRIPTION

ByCode View for [% app %]. 

=head1 SEE ALSO

L<[% app %]>

=head1 AUTHOR

[% author %]

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
