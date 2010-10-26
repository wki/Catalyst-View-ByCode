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
        push  => 'add_open_tag',
        pop   => 'remove_open_tag',
        last  => 'current_tag',
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
    my $tag_name = shift || ''; #$tag_name = '' if (!defined($tag_name));
    
    my $e = new Catalyst::View::ByCode::Markup::Tag(tag => $tag_name, attr => {@_});
 
    $self->append($e);
    $self->add_open_tag($e);
    
    return;
}

sub close_tag {
    $_[0]->remove_open_tag;
    return;
}


sub add_tag {
    my $self = shift;
    my $tag_name = shift; $tag_name = '' if (!defined($tag_name));
    my $code = shift;
    
    my $tag_stack = $self->tag_stack;
    
    # HINT: methods versus some lines of inline code for speedup.
    
    # $self->open_tag($tag_name, @_);
    my $e = new Catalyst::View::ByCode::Markup::Tag(tag => $tag_name, attr => {@_});
    (scalar(@{$tag_stack}) ? $tag_stack->[-1] : $self)->add_content($e);
    
    if ($code) {
        push @{$tag_stack}, $e;
        my $text = $code->(@_);
        if (blessed($text) && $text->can('render')) {
            $e->add_content( Catalyst::View::ByCode::Markup::Element->new(content => $text->render) );
        } elsif (defined($text) && (ref($text) || $text ne '')) {
            $e->add_content( Catalyst::View::ByCode::Markup::EscapedText->new(content => "$text") );
        }
        pop @{$tag_stack};
    }
    
    return;
}

sub append {
    ($_[0]->has_opened_tag ? $_[0]->current_tag : $_[0])->add_content($_[1]);
    return;
    
    # my $self = shift;
    # my $content = shift;
    # 
    # ($self->has_opened_tag ? $self->current_tag : $self)->add_content($content);
    # 
    # return;
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
    $_[0]->current_tag->set_attr(@_[1..$#_]);
    return;
}

sub get_attr {
    return $_[0]->current_tag->get_attr($_[1]);
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
