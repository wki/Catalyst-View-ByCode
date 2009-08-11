package Catalyst::View::ByCode::Markup::Element::EscapedText;
use Moose;
extends 'Catalyst::View::ByCode::Markup::Element::Text';

override as_text => sub {
    return $_[0]->_html_escape(super()); ### FIXME: does not work

    my $self = shift;
    my $text = super();
    $text =~ s{([\"<>&\x{0000}-\x{001f}\x{007f}-\x{ffff}])}{sprintf('&#%d;', ord($1))}exmsg;

    return $text;
};

no Moose;
1;
