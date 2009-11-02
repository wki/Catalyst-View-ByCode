package Catalyst::View::ByCode::Widget::Wrapper::Base;
use Moose::Role;
use Catalyst::View::ByCode::Renderer ':default';

sub render_label {
    my $self = shift;
    
    label.label(for => $self->id) { $self->label };
}

sub render_class {
    my ( $self, $result ) = @_;

    $result ||= $self->result;
    my $class = '';
    if ( $self->css_class || $result->has_errors ) {
        my @css_class;
        push( @css_class, split( /[ ,]+/, $self->css_class ) ) if $self->css_class;
        push( @css_class, 'error' ) if $result->has_errors;
        # $class .= ' class="';
        # $class .= join( ' ' => @css_class );
        # $class .= '"';
    }
    return $class ? (class => join(' ', $class)) : ();
}

use namespace::autoclean;
1;
