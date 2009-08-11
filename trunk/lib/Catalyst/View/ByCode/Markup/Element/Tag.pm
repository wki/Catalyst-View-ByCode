package Catalyst::View::ByCode::Markup::Element::Tag;
use Moose;
extends 'Catalyst::View::ByCode::Markup::Element::Structured';

has tag => {
    is => 'rw',
    isa => 'Str',
};

has attr => {
    is => 'rw',
    isa => 'HashRef',
};

override as_text => sub {
    my $self = shift;

    # open tag
    # inner();
    # close tag
}

no Moose;
1;
