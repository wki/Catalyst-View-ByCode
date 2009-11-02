package Catalyst::View::ByCode::FormHandler;

use Moose::Role;

has '+widget_name_space' => ( default => sub { ['Catalyst::View::ByCode::Widget'] } );


no Moose::Role;
1;

=head1 NAME

Catalyst::View::ByCode::FormHandlerRenderer - Simple rendering routine for C::V::ByCode

=head1 SYNOPSIS

This is an experimental role for for applying to forms.

    package YourApp::Form::YourForm;
    use HTML::FormHandler::Moose;
    extends 'HTML::FormHandler';
    with 'Catalyst::View::ByCode::FormHandler';
    
    has_field 'bla' => ( ... );
    # more fields...
    
    1;

=head1 DESCRIPTION

=head1 AUTHORS

See CONTRIBUTORS in L<HTML::FormHandler>
Adapted from HTML::FormHandler::Render::Simply by W. Kinkeldei

=head1 COPYRIGHT

This library is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
