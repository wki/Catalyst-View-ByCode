# -*- perl -*-
use Test::More tests => 12;
use Test::Exception;

#
# can module get use'd ?
#
BEGIN { use_ok('Catalyst::View::ByCode::Markup::Element::Text') };

#
# instantiate a element
#
my $e;
lives_ok { $e = new Catalyst::View::ByCode::Markup::Element::Text() } 'empty new element lives';
isa_ok($e, 'Catalyst::View::ByCode::Markup::Element::Text', 'class is OK');
can_ok($e, 'content', 'as_text');
is($e->content, '', 'content is empty');
is("$e", '', 'stringified content is empty');

# modify content
$e->content('huhu');
is($e->content, 'huhu', 'content is right');
is($e->as_text, 'huhu', 'as_text is right');
is("x${e}x", 'xhuhux', 'stringified content is right');

# check escaping
$e->content('huhu"i"');
is($e->content, 'huhu"i"', 'unescaped content is right');
is($e->as_text, 'huhu"i"', 'unescaped as_text is right');
is("x${e}x", 'xhuhu"i"x', 'stringified unescaped content is right');
