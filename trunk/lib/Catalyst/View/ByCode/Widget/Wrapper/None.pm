package Catalyst::View::ByCode::Widget::Wrapper::None;
use Moose::Role;
#use Catalyst::View::ByCode::Renderer ':default';

sub wrap_field { $_[2] }

use namespace::autoclean;
1;
