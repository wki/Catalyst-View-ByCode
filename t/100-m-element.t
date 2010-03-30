# -*- perl -*-
use Test::More;
use Test::Exception;

#
# can module get use'd ?
#
BEGIN { use_ok('Catalyst::View::ByCode::Markup::Element') };

#
# instantiate a element
#
my $e;
lives_ok { $e = new Catalyst::View::ByCode::Markup::Element() } 'empty new element lives';
isa_ok($e, 'Catalyst::View::ByCode::Markup::Element', 'class is OK');
can_ok($e, qw(content as_string _html_escape));
is($e->content, '', 'content is empty');
is("$e", '', 'stringified content is empty');

#
# check low level escaping
#
is($e->_html_escape('hello'), 'hello', 'escaping "hello" works');
is($e->_html_escape('<hello'), '&#60;hello', 'escaping "<hello" works');
is($e->_html_escape('<hello, "you"'), '&#60;hello, &#34;you&#34;', 'escaping "<hello \'you\'" works');

#
# modify content
#
$e->content('huhu');
is($e->content, 'huhu', 'content is right');
is($e->as_string, 'huhu', 'as_string is right');
is("x${e}x", 'xhuhux', 'stringified content is right');

done_testing();
