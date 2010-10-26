package Catalyst::View::ByCode::Markup::Structured;
use Moose;
use MooseX::AttributeHelpers;
extends 'Catalyst::View::ByCode::Markup::Element';

has content => (
    metaclass => 'Collection::Array',
    is => 'rw',
    isa => 'ArrayRef[Any]',
    lazy => 1,
    default => sub { [] },
    provides => {
        push  => 'add_content',
        empty => 'has_content',
    },
);

override as_string => sub {
    my $self = shift;
    my $indent_level = shift || 0;
    my $need_break = shift;

    return join('', 
                map { ref($_)
                        ? $_->as_string($indent_level+1, $need_break)
                        : defined($_) && $_ ne ''
                            ? do {
                                  s{([\"<>&\x{0000}-\x{001f}\x{007f}-\x{ffff}])}{sprintf('&#%d;', ord($1))}oexmsg;
                                  $_;
                              }
                            : ''
                }
                @{$self->content});
};

__PACKAGE__->meta->make_immutable;
no Moose;
1;
