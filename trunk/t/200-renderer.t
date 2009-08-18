# -*- perl -*-
use Test::More tests => 17;
use Test::Exception;

#
# can module get use'd ?
#
BEGIN { use_ok('Catalyst::View::ByCode::Renderer', ':markup') };

#
# exported subs
#
can_ok('Catalyst::View::ByCode::Renderer', qw(clear_markup init_markup get_markup markup_object));
can_ok('Catalyst::View::ByCode::Renderer', qw(template block block_content
                                              load yield attr class id on
                                              stash c doctype)); ### FIXME: _ fails
can_ok('main', qw(clear_markup init_markup get_markup markup_object));

#
# document handling
#
lives_ok {markup_object()} 'getting initial markup object lives';
is(markup_object(), undef, 'initial markup object is undef');
lives_ok {init_markup()} 'initing markup lives';

ok(defined(markup_object()), 'initial markup object is defined');
isa_ok(markup_object(), 'Catalyst::View::ByCode::Markup::Document', 'markup object is Document');

lives_ok {get_markup()} 'getting markup lives';
is(get_markup(), '', 'empty markup is empty');

lives_ok {clear_markup()} 'clearing markup lives';
is(markup_object(), undef, 'cleared markup object is undef');

#
# filling some markup manually
#
lives_ok {init_markup()} 'initing markup 2 lives';
isa_ok(markup_object(), 'Catalyst::View::ByCode::Markup::Document', 'markup object 2 is Document');

lives_ok {markup_object->add_tag('div', id => 42)} 'adding a tag works';
like(get_markup(), qr{\s*<div\s+id="42">\s*</div>\s*}xms, 'markup looks good');
