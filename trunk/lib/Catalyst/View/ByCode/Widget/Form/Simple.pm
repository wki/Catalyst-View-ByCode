package Catalyst::View::ByCode::Widget::Form::Simple;
use Moose::Role;
use Catalyst::View::ByCode::Renderer ':default';

has 'auto_fieldset' => ( isa => 'Bool', is => 'rw', lazy => 1, default => 1 );

sub render {
    my $self = shift;
    
    warn "CVBW::Form::Simple::render";

    my $result;
    my $form;
    if ( $self->DOES('HTML::FormHandler::Result') ) {
        $result = $self;
        $form   = $self->form;
    } else {
        $result = $self->result;
        $form   = $self;
    }

    form {
        attr action => $form->action if ($form->action);
        id $form->name if ($form->name);
        attr method => $form->http_method if ($form->http_method);
        attr enctype => $form->enctype if ($form->enctype);
        
        if ($form->form->auto_fieldset) {
            fieldset.main_fieldset {
                $self->render_fields($result,$form);
            }
        } else {
            $self->render_fields($result,$form);
        }
        '';
    };
    
}

sub render_fields {
    my $self = shift;
    my $result = shift;
    my $form = shift;
    
    foreach my $fld_result ( $result->results ) {
        die "no field in result for " . $fld_result->name unless $fld_result->field_def;
        pre { $fld_result->render };
    }
}

use namespace::autoclean;

1;
