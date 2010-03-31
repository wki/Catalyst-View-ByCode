# -*- perl -*-
use Test::More;
use Test::Exception;

#
# can module get use'd ?
#
BEGIN { use_ok('Catalyst::View::ByCode::Markup::Tag') };

#
# low-level: check camelCase key unification
#
my $key = *{"Catalyst::View::ByCode::Markup::Tag::_key"}{CODE};
is($key->('somename'), 'somename', 'lower case stays the same');
is($key->('someName'), 'some-name', 'single camel case works');
is($key->('someNAme'), 'some-n-ame', 'multi camel case works');
is($key->('some_name'), 'some-name', 'dashed names work');
is($key->('some_Name'), 'some--name', 'dashed Camel names work');
is($key->('Somename'), '-somename', 'dashed beginning works');
is($key->('_somename'), '-somename', 'underscored beginning works');
is($key->('somenamE'), 'somenam-e', 'Camel ending works');
is($key->('somename_'), 'somename-', 'underscored ending works');

#
# low-level: check attr stringification
#
my $str = *{"Catalyst::View::ByCode::Markup::Tag::_stringify_attr_value"}{CODE};
is($str->('a string'), 'a string', 'scalar values are stringified right');
is($str->(undef), undef, 'undef is stringified right');
is($str->([qw(abc xyz)]), 'abc xyz', 'array ref is stringified right');
is($str->({foo => 'bar'}), 'foo:bar', 'hash ref 1 is stringified right');
is($str->({foo => 'bar', zzz => 42}), 'foo:bar;zzz:42', 'hash ref 2 is stringified right');
is($str->({zIndex => 1000}), 'z-index:1000', 'hash ref 3 is stringified right');
my $bla = \'haha';
is($str->($bla), "$bla", 'other ref is stringified right');

#
# instantiate a element
#
my $e;
lives_ok { $e = new Catalyst::View::ByCode::Markup::Tag() } 'empty new element lives';
isa_ok($e, 'Catalyst::View::ByCode::Markup::Tag', 'class is OK');
can_ok($e, qw(content as_string tag attr has_attr attrs get_attr set_attr delete_attr));
is_deeply($e->content, [], 'content is empty array-ref');
is("$e", '', 'stringified content is empty');

#
# generate an empty tag w/o attrs
#
$e->tag('xxx');
is($e->as_string, '<xxx></xxx>', 'tag w/o content is OK');
is("+$e+", '+<xxx></xxx>+', 'stringified tag w/o content is OK');
is_deeply([$e->attrs], [], 'list of attrs is empty');


#
# add an attr manually
#
dies_ok { $e->attr('$in#valid?' => '123') } 'invalid attr names must die';
# fails:
#dies_ok { $e->set_attr('$in#valid?' => '123') } 'invalid attr names must die';


$e->attr({abc => '42'});
is($e->as_string, '<xxx abc="42"></xxx>', 'tag w/ attr w/o content is OK');
is("zz$e", 'zz<xxx abc="42"></xxx>', 'stringified tag w/ attr w/o content is OK');
is_deeply([$e->attrs], ['abc'], 'list of attrs is "abc"');
ok($e->has_attr('abc'), 'attr "abc" reported as existing');

$e->attr({abc => '4<2'});
is($e->as_string, '<xxx abc="4&#60;2"></xxx>', 'tag w/ attr w/o content is OK');
is("ii$e", 'ii<xxx abc="4&#60;2"></xxx>', 'stringified tag w/ attr w/o content is OK');

$e->attr->{x12} = 'hello';
is($e->as_string, '<xxx abc="4&#60;2" x12="hello"></xxx>', 'tag w/ attr w/o content is OK');
is("123$e", '123<xxx abc="4&#60;2" x12="hello"></xxx>', 'stringified tag w/ attr w/o content is OK');
is_deeply([sort $e->attrs], ['abc', 'x12'], 'list of attrs is "abc", "x12"');

$e->set_attr(x12 => 'blabla');
is($e->as_string, '<xxx abc="4&#60;2" x12="blabla"></xxx>', 'tag w/ attr w/o content is OK');

$e->delete_attr('x12');
is($e->as_string, '<xxx abc="4&#60;2"></xxx>', 'tag w/ attr w/o content is OK');

$e->set_attr(wot => [1, 'a', 42]);
is_deeply($e->attr->{wot}, [1, 'a', 42], 'array-ref attr is possible');
is($e->as_string, '<xxx abc="4&#60;2" wot="1 a 42"></xxx>', 'tag w/ array-attr gets stringified OK');
$e->delete_attr('wot');

$e->set_attr(zap => {uu => 'ijklm'});
is_deeply($e->attr->{zap}, {uu => 'ijklm'}, 'hash-ref attr is possible');
is($e->as_string, '<xxx abc="4&#60;2" zap="uu:ijklm"></xxx>', 'tag w/ hash-attr gets stringified OK');
$e->delete_attr('zap');
$e->delete_attr('abc');

$e->set_attr(someAttr => 42);
is($e->as_string, '<xxx some-attr="42"></xxx>', 'tag w/ mixedCase attr gets stringified OK');
$e->delete_attr('someAttr');

$e->set_attr(my_attr => 4711);
is($e->as_string, '<xxx my-attr="4711"></xxx>', 'tag w/ combined_name attr gets stringified OK');
$e->delete_attr('my_attr');

$e->set_attr(style => {zIndex => 1000});
is($e->as_string, '<xxx style="z-index:1000"></xxx>', 'tag w/ mixedCase hashref-key gets stringified OK');
$e->delete_attr('style');

#
# check auto-expansion for checked, disabled and selected
#
my %value_for = (zero => 0, undef => undef, 'number:"1"' => 1, 'string:"abc"' => 'abc');
foreach my $attr_name (qw(checked disabled multiple readonly selected)) {
    while (my ($name, $value) = each(%value_for)) {
        $e->set_attr($attr_name => $value);
        my $attr = $value ? qq{ $attr_name="$attr_name"} : '';
        is($e->as_string, "<xxx$attr></xxx>", "tag w/ $name $attr_name attr gets stringified OK");
        $e->delete_attr($attr_name);
    }
}

#
# add some content
#
$e->set_attr(abc => '4<2');
my $c = new Catalyst::View::ByCode::Markup::Element(content => 'blabla');
$e->content([$c]);
is($e->as_string, '<xxx abc="4&#60;2">blabla</xxx>', 'tag w/ attr w/ content is OK');
is("pp$e", 'pp<xxx abc="4&#60;2">blabla</xxx>', 'stringified tag w/ attr w/ content is OK');


done_testing();
