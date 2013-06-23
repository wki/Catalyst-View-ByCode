package TestApp::View::ByCode;
use Moose;
extends 'Catalyst::View::ByCode';

__PACKAGE__->config(
    # unchanged:
    # extension => '.pl',
    # 
    # set here
    root_dir => 'xxroot/xxbycode',
    # 
    # set in application, must read:
    # wrapper => 'xxx.pl',
    #
    # set at both places, app (which wins) and here:
    include => ['List::Util'],
);

1;
