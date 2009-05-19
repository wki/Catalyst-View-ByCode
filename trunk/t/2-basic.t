# -*- perl -*-

use Test::More no_plan;
use Test::Exception;

#
# can module get use'd ?
#
BEGIN { use_ok('Catalyst::View::ByCode::Helper') };
use Catalyst::View::ByCode::Helper qw(:default);

#
# check if routines exported to here
# using is deprecated
#
can_ok('main', qw(clear_markup init_markup get_markup markup_object 
                  doctype load 
                  with attr using fill data set_global_data 
                  apply 
                  class id on 
                  get_trail set_trail));

#
# check some HTML-Tags
#
can_ok('main', 'div');
can_ok('main', 'body');
can_ok('main', 'span');
can_ok('main', 'h3');

