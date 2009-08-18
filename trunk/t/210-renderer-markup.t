# -*- perl -*-
use Test::More tests => 25;
use Test::Exception;

#
# can module get use'd ?
#
BEGIN { use_ok('Catalyst::View::ByCode::Renderer', ':default') };

#
# exported subs
#
can_ok('main', qw(template block block_content
                  load yield attr class id on
                  stash c doctype _
                  div span h1));

ok(!main->can('clear_markup'),  'clear_markup not exported');
ok(!main->can('init_markup'),   'init_markup not exported');
ok(!main->can('get_markup'),    'get_markup not exported');
ok(!main->can('markup_object'), 'markup_object not exported');

#
# clear markup
#
lives_ok {Catalyst::View::ByCode::Renderer::init_markup()} 'initing markup lives';
is(Catalyst::View::ByCode::Renderer::get_markup(), '', 'markup is empty');

#
# defining a template
#
ok(!main->can('RUN'), 'sub RUN initially undefined');
lives_ok { template { print OUT 'bla' }; } 'defining a template works';
ok(main->can('RUN'), 'sub RUN defined by template directive');

is(Catalyst::View::ByCode::Renderer::get_markup(), '', 'markup still empty');

lives_ok { RUN() } 'RUN can get called';
is(Catalyst::View::ByCode::Renderer::get_markup(), 'bla', 'markup contains template result');

#
# defining a block
#
ok(!main->can('some_block'), 'sub some_block initially undefined');
# must be eval()ed because Devel::Declare defines the block as soon as 'block' is scanned by compiler
lives_ok { eval q{ package main; block some_block { return 'was inside block' } }; die $@ if $@; } 'block definition works';
ok(main->can('some_block'), 'sub some_block now defined');

#
# adding things to a fresh document
#
lives_ok {Catalyst::View::ByCode::Renderer::init_markup()} 'initing markup 2 lives';
is(Catalyst::View::ByCode::Renderer::get_markup(), '', 'markup 2 is empty');

lives_ok { div { attr abc => 42 }; } 'adding a div lives';
like(Catalyst::View::ByCode::Renderer::get_markup(), qr{\s*<div\s+abc="42">\s*</div>\s*}xms, 'markup2 looks OK');

#
# adding things to a fresh document and calling block
#
lives_ok {Catalyst::View::ByCode::Renderer::init_markup()} 'initing markup 3 lives';
is(Catalyst::View::ByCode::Renderer::get_markup(), '', 'markup 3 is empty');

lives_ok { div { id 'xyz'; b { some_block(); }; }; } 'adding a div with block lives';
like(Catalyst::View::ByCode::Renderer::get_markup(), qr{\s*<div\s+id="xyz">\s*<b>\s*was\s+inside\s+block\s*</b>\s*</div>\s*}xms, 'markup3 looks OK');

