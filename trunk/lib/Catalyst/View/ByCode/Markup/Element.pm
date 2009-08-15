package Catalyst::View::ByCode::Markup::Element;
use Moose;

has content => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => '',
);

use overload '""' => sub { $_[0]->as_text() }, fallback => 1;

sub as_text { $_[0]->content }

sub _html_escape {
    my ($self, $text) = @_;

    $text =~ s{([\"<>&\x{0000}-\x{001f}\x{007f}-\x{ffff}])}{sprintf('&#%d;', ord($1))}exmsg;
    return $text;
}

no Moose;
1;