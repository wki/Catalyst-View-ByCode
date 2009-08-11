package Catalyst::View::ByCode::Markup::Element;
use Moose;

has content => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub { '' },
);

use overload '""' => \&as_text, fallback => 1;

sub as_text { $_[0]->content }

no Moose;
1;
