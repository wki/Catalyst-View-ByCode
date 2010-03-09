package Catalyst::View::ByCode::Markup::Document;
use Moose;
use MooseX::AttributeHelpers;
use Catalyst::View::ByCode::Markup::Element;
use Catalyst::View::ByCode::Markup::EscapedText;
use Catalyst::View::ByCode::Markup::Tag;
extends 'Catalyst::View::ByCode::Markup::Structured';

has tag_stack => (
    metaclass => 'Collection::Array',
    is => 'rw',
    isa => 'ArrayRef[Object]',
    lazy => 1,
    default => sub { [] },
    provides => {
        push => 'add_open_tag',
        pop => 'remove_open_tag',
        last => 'current_tag',
        empty => 'has_opened_tag',
    },
);

override as_string => sub {
    my $self = shift;
    # ignore indentation my $indent_level = shift || 0;

    my $need_break = 1;
    return join('', map {$_->as_string(0, \$need_break)} @{$self->content});
};

sub open_tag {
    my $self = shift;
    my $tag_name = shift;
    $tag_name = '' if (!defined($tag_name));
    
    my $e = new Catalyst::View::ByCode::Markup::Tag(tag => $tag_name, attr => {@_});
 
    $self->append($e);
    $self->add_open_tag($e);
    
    return;
}

sub close_tag {
    my $self = shift;
    
    die 'no tag open' if (!$self->has_opened_tag);
    
    $self->remove_open_tag;
    
    return;
}

sub add_tag {
    my $self = shift;
    
    $self->open_tag(@_);
    $self->close_tag;
    
    return;
}

sub append {
    my $self = shift;
    my $content = shift;

    ($self->has_opened_tag ? $self->current_tag : $self)->add_content($content);
    
    return;
}

sub add_text {
    my $self = shift;
    my $text = shift;
    my $raw = shift || 0;

    return if (!defined($text) || (!ref($text) && $text eq ''));
    
    if (blessed($text)) {
        if ($text->can('render')) {
            # looks like a H::FormFu / H::FormHandler object...
            # always print unescaped (trust the authors)
            $self->add_text($text->render(), 1);
        } else {
            ### TODO: can we do more things that act natural?
            $self->add_text("$text");
        }
    } elsif (ref($text)) {
        # TODO -- do something meaningful
    } else {
        my $class = 'Catalyst::View::ByCode::Markup::' . ($raw ? 'Element' : 'EscapedText');
        $self->append($class->new(content => $text));
    }
    return;
}

sub set_attr {
    my $self = shift;
    
    die 'no tag open' if (!$self->has_opened_tag);
    die 'no attr given' if (!scalar(@_));
    
    $self->current_tag->set_attr(@_);
    
    return;
}

sub get_attr {
    my $self = shift;
    my $attr_name = shift;
    
    die 'no tag open' if (!$self->has_opened_tag);
    die 'no attr-name given' if (!$attr_name);
    
    return $self->current_tag->get_attr($attr_name);
}

no Moose;
1;
