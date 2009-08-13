# -*- perl -*-
use Test::More tests => 17;
use Test::Exception;

#
# can module get use'd ?
#
BEGIN { use_ok('Catalyst::View::ByCode::Markup::Document') };


#
# instantiate a document
#
my $d;
lives_ok { $d = new Catalyst::View::ByCode::Markup::Document() } 'empty new element lives';
isa_ok($d, 'Catalyst::View::ByCode::Markup::Document', 'class is OK');
can_ok($d, qw(content as_text 
              add_content has_content
              tag_stack add_open_tag remove_open_tag current_tag has_opened_tag
              open_tag close_tag add_tag
              append add_text
              set_attr));
is_deeply($d->content, [], 'content is empty array-ref');
is($d->as_text, '', 'content is empty');
is("$d", '', 'stringified content is empty');
ok(!$d->has_content, 'has_content reports empty');
ok(!$d->has_opened_tag, 'has_opened_tag reports closed');

#
# open and close a tag
#
$d->open_tag('div', id => 42);
ok($d->has_content, 'has_content reports content');
ok($d->has_opened_tag, 'has_opened_tag reports open');
like($d->as_text, qr{<div\s+id="42">\s*</div>}xms, 'content is <div>');
is($d->current_tag->tag, 'div', 'current tag is <div>');

$d->add_text('huhu');
like($d->as_text, qr{<div\s+id="42">\s*huhu\s*</div>}xms, 'content is <div id>huhu</div>');

$d->current_tag->set_attr(id => 97);

$d->set_attr(class => 'fghi');
like($d->as_text, qr{<div\s+class="fghi"\s+id="97">\s*huhu\s*</div>}xms, 'content is <div class id>huhu</div>');

$d->close_tag;
ok(!$d->has_opened_tag, 'has_opened_tag reports closed');

$d->add_text('the end');
like($d->as_text, qr{<div\s+class="fghi"\s+id="97">\s*huhu\s*</div>\s*the\s+end}xms, 'content is <div class id>huhu</div>the end');

