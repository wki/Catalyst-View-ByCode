# -*- perl -*-
use Test::More tests => 15;
use Test::Exception;

#
# can module get use'd ?
#
BEGIN { use_ok('Catalyst::View::ByCode::Markup::Element::Tag') };
#use Catalyst::View::ByCode::Markup::Element::Text;
#use Catalyst::View::ByCode::Markup::Element::EscapedText;


#
# instantiate a element
#
my $e;
lives_ok { $e = new Catalyst::View::ByCode::Markup::Element::Tag() } 'empty new element lives';
isa_ok($e, 'Catalyst::View::ByCode::Markup::Element::Tag', 'class is OK');
can_ok($e, qw(content as_text tag attr));
is_deeply($e->content, [], 'content is empty array-ref');
is("$e", '', 'stringified content is empty');

#
# generate an empty tag w/o attrs
#
$e->tag('xxx');
is($e->as_text, '<xxx></xxx>', 'tag w/o content is OK');

#
# add an attr
#
$e->attr({abc => '42'});
is($e->as_text, '<xxx abc="42"></xxx>', 'tag w/ attr w/o content is OK');
is("zz$e", 'zz<xxx abc="42"></xxx>', 'stringified tag w/ attr w/o content is OK');

$e->attr({abc => '4<2'});
is($e->as_text, '<xxx abc="4&#60;2"></xxx>', 'tag w/ attr w/o content is OK');
is("ii$e", 'ii<xxx abc="4&#60;2"></xxx>', 'stringified tag w/ attr w/o content is OK');

$e->attr->{x12} = 'hello';
is($e->as_text, '<xxx abc="4&#60;2" x12="hello"></xxx>', 'tag w/ attr w/o content is OK');
is("123$e", '123<xxx abc="4&#60;2" x12="hello"></xxx>', 'stringified tag w/ attr w/o content is OK');

#
# add some content
#
my $c = new Catalyst::View::ByCode::Markup::Element(content => 'blabla');
$e->content([$c]);
is($e->as_text, '<xxx abc="4&#60;2" x12="hello">blabla</xxx>', 'tag w/ attr w/ content is OK');
is("pp$e", 'pp<xxx abc="4&#60;2" x12="hello">blabla</xxx>', 'stringified tag w/ attr w/ content is OK');
