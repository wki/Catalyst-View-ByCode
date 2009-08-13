# -*- perl -*-
use Test::More tests => 1;
use Test::Exception;

#
# can module get use'd ?
#
BEGIN { use_ok('Catalyst::View::ByCode::Renderer') };
