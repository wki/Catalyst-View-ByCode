# -*- perl -*-
use Test::More tests => 13;
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
can_ok($e, qw(content as_text has_content add_content));
is_deeply($e->content, [], 'content is empty array-ref');
is("$e", '', 'stringified content is empty');
ok(!$e->has_content, 'has_content() reports empty');
my $ut = new Catalyst::View::ByCode::Markup::Element::Text(content => 'hello');

#
# add content manually
#
$e->content([$ut]);
ok($e->has_content, 'has_content() reports non-empty');
is($e->as_text, 'hello', '1 element content renders fine');
is("$e", 'hello', 'stringified 1 element content renders fine');

#
# add content my accessor
#
my $et = new Catalyst::View::ByCode::Markup::Element::EscapedText(content => '<hello');
$e->add_content($et);
ok($e->has_content, 'has_content() still reports non-empty');
is($e->as_text, 'hello&#60;hello', 'combination renders fine');
is("$e", 'hello&#60;hello', 'stringified combination renders fine');
