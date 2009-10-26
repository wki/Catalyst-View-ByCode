package Catalyst::View::ByCode::FormHandlerRenderer;

use Moose::Role;
use Catalyst::View::ByCode::Renderer ':default';

requires( 'sorted_fields', 'field' );

our $VERSION = 0.01;

=head1 NAME

Catalyst::View::ByCode::FormHandlerRenderer - Simple rendering routine for C::V::ByCode

=head1 SYNOPSIS

This is a Moose role that is an example of a very simple rendering
routine for L<HTML::FormHandler>. It has almost no features, but can
be used as an example for producing something more complex.
The idea is to produce your own custom rendering roles...

You are advised to create a copy of this module for use in your
forms, since it is not possible to make improvements to this module
and maintain backwards compatibility.

In your Form class:

   package MyApp::Form::Silly;
   use Moose;
   extends 'HTML::FormHandler::Model::DBIC';
   with 'Catalyst::View::ByCode::FormHandlerRenderer';

In a template:

   stash->{form}->render;

or for individual fields:

   stash->{form}->field_render( 'title' );


=head1 DESCRIPTION

This role provides HTML output routines for the 'widget' types
defined in the provided FormHandler fields. Each 'widget' name
has a 'widget_$name' method here.

These widget routines output strings with HTML suitable for displaying
form fields.

The widget for a particular field can be defined in the form. You can
create additional widget routines in your form for custom widgets.

=cut

=head2 render

To render all the fields in a form in sorted order (using
'sorted_fields' method).

=head2 render_start, render_end

Will render the beginning and ending <form> tags and fieldsets. Allows for easy
splitting up of the form if you want to hand-render some of the fields.

   [% form.render_start %]
   [% form.render_field('title') %]
   <insert specially rendered field>
   [% form.render_field('some_field') %]
   [% form.render_end %]

=head2 render_field

Render a field passing in a field object or a field name

   $form->render_field( $field )
   $form->render_field( 'title' )

=head2 render_text

Output an HTML string for a text widget

=head2 render_password

Output an HTML string for a password widget

=head2 render_hidden

Output an HTML string for a hidden input widget

=head2 render_select

Output an HTML string for a 'select' widget, single or multiple

=head2 render_checkbox

Output an HTML string for a 'checkbox' widget

=head2 render_radio_group

Output an HTML string for a 'radio_group' selection widget.
This widget should be for a field that inherits from 'Select',
since it requires the existance of an 'options' array.

=head2 render_textarea

Output an HTML string for a textarea widget

=head2 render_compound

Renders field with 'compound' widget

=head2 render_submit

Renders field with 'submit' widget

=cut


has 'auto_fieldset' => ( isa => 'Bool', is => 'rw', default => 1 );
has 'label_types' => (
   metaclass  => 'Collection::Hash',
   isa        => 'HashRef[Str]',
   is         => 'rw',
   default    => sub { {
           text => 'label', 
           password => 'label', 
           'select' => 'label',  
           checkbox => 'label', 
           textarea => 'label',
           radio_group => 'label', 
           compound => 'legend',
           adjoin => 'label',
       }
   },
   auto_deref => 1,
   provides   => {
       get       => 'get_label_type',
   },
);

sub render {
    my $self = shift;

    form {
        attr action => $self->action if ($self->action);
        id $self->name if ($self->name);
        attr method => $self->http_method if ($self->http_method);
        
        if ($self->auto_fieldset) {
            fieldset.main_fieldset {
                $self->render_fields;
            }
        } else {
            $self->render_fields;
        }
        '';
    };
}

sub render_fields {
    my $self = shift;
    my $show_raw = shift || 0;
    
    $self->render_field($_, $show_raw) for $self->sorted_fields;
    
    if ($show_raw) {
        foreach my $field (grep {$_} map {$_->errors} ($self->sorted_fields)) {
            span.error_message { $field };
        }
    }
    
    return;
}

sub render_field {
    my( $self, $field, $show_raw ) = @_;

    $field = $self->field($field) if (!ref($field));

    die "must pass field to render_field"
        unless( defined $field && $field->isa('HTML::FormHandler::Field') );
    return if $field->widget eq 'no_render';
    my $field_method = 'render_' . $field->widget;
    die "Widget method $field_method not implemented in C::V::ByCode::FormHandlerRenderer"
        unless $self->can($field_method);
      
    if ($show_raw) {
        $self->$field_method($field);
    } else {
        my @class = ();
        if ($field->css_class || $field->has_errors) {
           push @class, $field->css_class if $field->css_class;
           push @class, 'error' if $field->has_errors;
        }
        
        div {
            class \@class if (scalar(@class));
            
            my $l_type = defined $self->get_label_type( $field->widget ) ? $self->get_label_type( $field->widget ) : '';
            if ($l_type eq 'label'){
                label.label {
                    attr for => $field->id;
                    $field->label . ': ';
                };
                
                $self->$field_method($field);
                span.error_message { $_ } for $field->errors;
            } elsif ($l_type eq 'legend') {
                fieldset {
                    class $field->html_name;
                    legend { $field->label };
                    
                    $self->$field_method($field);
                    span.error_message { $_ } for $field->errors;
                }
            } else {
                $self->$field_method($field);
            }
            ''; # suppress if's return...
        };
    }
    
    return;
}

sub render_text {
   my ( $self, $field ) = @_;

   input(type => 'text') {
       id $field->id;
       attr name => $field->html_name;
       attr size => $field->size if $field->size;
       attr maxlength => $field->maxlength if $field->maxlength;
       attr value => $field->fif;
   };
}

sub render_password {
   my ( $self, $field ) = @_;

   input(type => 'password') {
       id $field->id;
       attr name => $field->html_name;
       attr size => $field->size if $field->size;
       attr maxlength => $field->maxlength if $field->maxlength;
       attr value => $field->fif;
   };
}

sub render_hidden {
   my ( $self, $field ) = @_;

   input(type => 'hidden') {
       id $field->id;
       attr name => $field->html_name;
       attr value => $field->fif;
   };
}

sub render_select {
   my ( $self, $field ) = @_;

   choice {
       id $field->id;
       attr name => $field->html_name;
       attr multiple => 1 if $field->multiple;
       attr size => $field->size if $field->size;

       my $index = 0;
       foreach my $option ( $field->options ) {
           option(value => $option->{value}, id => $field->id) {
               if ($field->fif) {
                   if ($field->multiple == 1) {
                       my @fif;
                       if (ref $field->fif) {
                           @fif = @{ $field->fif };
                       } else {
                           @fif = ( $field->fif );
                       }
                       foreach my $optval (@fif) {
                           attr selected => 1 if $optval == $option->{value};
                       }
                   } else {
                       attr selected => 1 if $option->{value} eq $field->fif;
                   }
               }
               $option->{value};
           };
           $index++;
       }
   };
}

sub render_checkbox {
   my ( $self, $field ) = @_;

   input(type => 'checkbox') {
       id $field->id;
       attr name => $field->html_name;
       attr value => $field->checkbox_value;
       attr checked => 1 if $field->fif eq $field->checkbox_value;
   };
}


sub render_radio_group {
   my ( $self, $field ) = @_;

   br;
   my $index = 0;
   foreach my $option ($field->options) {
       input(type => 'radio') {
           id $field->id;
           attr name => $field->html_name;
           attr value => $option->{value};
           attr checked => 1 if $option->{value} eq $self->fif;
       };
       print OUT $option->{label};
       br;
       $index++;
   }
}

sub render_textarea {
   my ( $self, $field ) = @_;

   textarea {
       id $field->id;
       attr name => $field->html_name;
       attr cols => $field->cols || 10;
       attr rows => $field->rows || 5;
       
       $field->fif;
   };
}

sub render_compound {
   my ( $self, $field ) = @_;

   warn "COMPOUND";
   $self->render_field($_) for $field->sorted_fields;
}

sub render_adjoin {
   my ( $self, $field ) = @_;

   warn "ADJOIN";
   $self->render_field($_, 1) for $field->sorted_fields;
}

sub render_submit {
   my ( $self, $field ) = @_;
   
   input(type => 'submit') {
       id $field->id;
       attr name => $field->html_name;
       attr value => $field->fif || '';
   };
}

=head1 AUTHORS

See CONTRIBUTORS in L<HTML::FormHandler>
Adapted from HTML::FormHandler::Render::Simply by W. Kinkeldei

=head1 COPYRIGHT

This library is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

no Moose::Role;
1;


