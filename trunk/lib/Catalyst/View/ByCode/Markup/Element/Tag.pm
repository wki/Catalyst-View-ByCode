package Catalyst::View::ByCode::Markup::Element::Tag;
use Moose;
extends 'Catalyst::View::ByCode::Markup::Element::Structured';

has tag => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => '',
);

has attr => (
    is => 'rw',
    isa => 'HashRef[Str]',
    lazy => 1,
    default => sub { {} },
);

override as_text => sub {
    my $self = shift;

    # just content if no tag name given
    return super() if (!$self->tag);
    
    # wrap content into a tag
    my $result = qq{<${\$self->tag}};
    $result .= qq{ $_="${\$self->_html_escape($self->attr->{$_})}"}
        for sort keys(%{$self->attr});
    $result .= '>';
    $result .= super();
    $result .= qq{</${\$self->tag}>};
    
    return $result;
};

no Moose;
1;
