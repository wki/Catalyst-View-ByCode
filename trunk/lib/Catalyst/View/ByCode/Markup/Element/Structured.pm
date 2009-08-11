package Catalyst::View::ByCode::Markup::Element::Structured;
use Moose;
extends 'Catalyst::View::ByCode::Markup::Element';

has content => (
    is => 'rw',
    isa => 'ArrayRef[Object]',
    lazy => 1,
    default => sub { [] },
);

override as_text => sub {
    my $self = shift;

    return join('', map {$_->as_text} @{$self->content});
};

no Moose;
1;
