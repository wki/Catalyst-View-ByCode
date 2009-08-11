package Catalyst::View::ByCode::Markup::Element::EscapedText;
use Moose;
extends 'Catalyst::View::ByCode::Markup::Element::Text';

override as_text => sub {
    my $self = shift;

    my $text = inner();
    $text =~ s{([\"<>&\x{0000}-\x{001f}\x{007f}-\x{ffff}])}{sprintf('&#%d;', ord($1))}exmsg;

    return $text;
}

no Moose;
1;
