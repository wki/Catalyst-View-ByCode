package Catalyst::View::ByCode::Markup::Element::Tag;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::AttributeHelpers;
extends 'Catalyst::View::ByCode::Markup::Element::Structured';

type 'AttrName' #=> as 'Str';
;#    => where { m{\A (a-zA-Z0-9-_)+ \z}xms };

#coerce 'AttrName'
#    => from 'Str'
#       => where { qr{\A (a-zA-Z0-9-_)+ \z}xms };

has tag => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => '',
);

has attr => (
    metaclass => 'Collection::Hash',
    is => 'rw',
    isa => 'HashRef[AttrName]',
    lazy => 1,
    default => sub { {} },
    # coerce => 1,
    provides => {
        exists => 'has_attr',
        keys   => 'attrs',
        get    => 'get_attr',
        set    => 'set_attr',
        delete => 'delete_attr',
    },
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
