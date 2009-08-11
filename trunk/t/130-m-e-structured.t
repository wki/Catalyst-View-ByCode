# -*- perl -*-
use Test::More tests => 7;
use Test::Exception;

#
# can module get use'd ?
#
BEGIN { use_ok('Catalyst::View::ByCode::Markup::Element::Structured') };
use Catalyst::View::ByCode::Markup::Element::Text;
use Catalyst::View::ByCode::Markup::Element::EscapedText;


#
# instantiate a element
#
my $e;
lives_ok { $e = new Catalyst::View::ByCode::Markup::Element::Structured() } 'empty new element lives';
isa_ok($e, 'Catalyst::View::ByCode::Markup::Element::Structured', 'class is OK');
can_ok($e, qw(content as_text));
is_deeply($e->content, [], 'content is empty array-ref');
is("$e", '', 'stringified content is empty');

my $ut = new Catalyst::View::ByCode::Markup::Element::Text(content => 'hello');
my $et = new Catalyst::View::ByCode::Markup::Element::EscapedText(content => '<hello');

$e->content([$ut, $et]);

is($e->as_text, 'hello&#60;hello', 'combination renders fine');
# # modify content
# $e->content('huhu');
# is($e->content, 'huhu', 'content is right');
# is($e->as_text, 'huhu', 'as_text is right');
# is("x${e}x", 'xhuhux', 'stringified content is right');

