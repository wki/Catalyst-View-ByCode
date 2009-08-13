package Catalyst::View::ByCode::Markup::Structured;
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
    my $indent_level = shift || 0;
    my $need_break = shift;

    return join('', map {$_->as_text($indent_level+1, $need_break)} @{$self->content});
};

no Moose;
1;
