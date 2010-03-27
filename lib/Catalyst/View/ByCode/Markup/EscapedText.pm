package Catalyst::View::ByCode::Markup::EscapedText;
use Moose;
extends 'Catalyst::View::ByCode::Markup::Element';

override as_string => sub {
    return $_[0]->_html_escape(super());

    # my $self = shift;
    # my $text = super();
    # $text =~ s{([\"<>&\x{0000}-\x{001f}\x{007f}-\x{ffff}])}{sprintf('&#%d;', ord($1))}exmsg;
    # 
    # return $text;
};

no Moose;
1;
