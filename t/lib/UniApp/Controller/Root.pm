package UniApp::Controller::Root;
use Moose;
use Encode 'is_utf8';
BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config(namespace => '');

sub index :Path() :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('index works');
}

sub simple_template :Local :Args {
    my ( $self, $c, @extras ) = @_;

    $c->forward('View::ByCode');
}

sub unicode_output :Local :Args {
    my ( $self, $c ) = @_;

    $c->forward('View::ByCode');
}

sub raw_output :Local :Args {
    my ( $self, $c ) = @_;

    $c->forward('View::ByCode');
}

sub fake_output :Local :Args {
    my ( $self, $c ) = @_;

    # LATIN SMALL LETTER O WITH DIAERESIS
    # Unicode: U+00F6, UTF-8: C3 B6

    # CYRILLIC CAPITAL LETTER EF
    # Unicode: U+0424, UTF-8: D0 A4

    my $string = "foo\x{00f6}\x{0424}bar";
    die 'not a unicode string'
        if !is_utf8 $string;

    $c->res->body($string);
}


1;
