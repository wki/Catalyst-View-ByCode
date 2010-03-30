# -*- perl -*-
use Test::More;
use Test::Exception;

#
# can module get use'd ?
#
BEGIN { use_ok('Catalyst::View::ByCode::Markup::Structured') };
use Catalyst::View::ByCode::Markup::Element;
use Catalyst::View::ByCode::Markup::EscapedText;


#
# instantiate a element
#
my $e;
lives_ok { $e = new Catalyst::View::ByCode::Markup::Structured() } 'empty new element lives';
isa_ok($e, 'Catalyst::View::ByCode::Markup::Structured', 'class is OK');
can_ok($e, qw(content as_string has_content add_content));
is_deeply($e->content, [], 'content is empty array-ref');
is("$e", '', 'stringified content is empty');
ok(!$e->has_content, 'has_content() reports empty');

#
# add content manually
#
my $ut = new Catalyst::View::ByCode::Markup::Element(content => 'hello');
$e->content([$ut]);
ok($e->has_content, 'has_content() reports non-empty');
is($e->as_string, 'hello', '1 element content renders fine');
is("$e", 'hello', 'stringified 1 element content renders fine');

#
# add content my accessor
#
my $et = new Catalyst::View::ByCode::Markup::EscapedText(content => '<hello');
$e->add_content($et);
ok($e->has_content, 'has_content() still reports non-empty');
is($e->as_string, 'hello&#60;hello', 'combination renders fine');
is("$e", 'hello&#60;hello', 'stringified combination renders fine');

done_testing();
