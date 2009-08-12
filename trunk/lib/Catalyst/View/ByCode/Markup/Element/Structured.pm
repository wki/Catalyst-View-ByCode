package Catalyst::View::ByCode::Markup::Element::Structured;
use Moose;
use MooseX::AttributeHelpers;
extends 'Catalyst::View::ByCode::Markup::Element';

has content => (
    metaclass => 'Collection::Array',
    is => 'rw',
    isa => 'ArrayRef[Object]',
    lazy => 1,
    default => sub { [] },
    provides => {
        push => 'add_content',
        empty => 'has_content',
    },
);

override as_text => sub {
    my $self = shift;

    return join('', map {$_->as_text} @{$self->content});
};

no Moose;
1;
