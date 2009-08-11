# -*- perl -*-
use Test::More tests => 12;
use Test::Exception;

#
# can module get use'd ?
#
BEGIN { use_ok('Catalyst::View::ByCode::Markup::Element::EscapedText') };

#
# instantiate a element
#
my $e;
lives_ok { $e = new Catalyst::View::ByCode::Markup::Element::EscapedText() } 'empty new element lives';
isa_ok($e, 'Catalyst::View::ByCode::Markup::Element::EscapedText', 'class is OK');
can_ok($e, 'content', 'as_text');
is($e->content, '', 'content is empty');
is("$e", '', 'stringified content is empty');

# modify content
$e->content('huhu');
is($e->content, 'huhu', 'content is right');
is($e->as_text, 'huhu', 'content is right');
is("x${e}x", 'xhuhux', 'stringified content is right');

# check escaping
$e->content('huhu"i"');
is($e->content, 'huhu"i"', 'content is right');
is($e->as_text, 'huhu&#34;i&#34;', 'escaped content is right');
is("x${e}x", 'xhuhu&#34;i&#34;x', 'stringified escaped content is right');
