package IntApp::Controller::Root;
use Moose;
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

1;
