package Catalyst::View::ByCode::Widget::Wrapper::Simple;
use Moose::Role;
with 'Catalyst::View::ByCode::Widget::Wrapper::Base';
use Catalyst::View::ByCode::Renderer ':default';

sub wrap_field {
    my ( $self, $result, $rendered_widget ) = @_;

    div {
        #class render_class(...)
        # if ( $self->has_flag('is_compound') ) {
        #     $output .= '<fieldset class="' . $self->html_name . '">';
        #     $output .= '<legend>' . $self->label . '</legend>';
        # }
        # elsif ( !$self->has_flag('no_render_label') && $self->label ) {
        #     $output .= $self->render_label;
        # }
        # $output .= $rendered_widget;
        # $output .= qq{\n<span class="error_message">$_</span>} for $result->all_errors;
        # if ( $self->has_flag('is_compound') ) {
        #     $output .= '</fieldset>';
        # }
    };
}

use namespace::autoclean;
1;
