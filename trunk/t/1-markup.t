# -*- perl -*-

use Test::More no_plan;
use Test::Exception;

#
# can module get use'd ?
#
BEGIN { use_ok('Catalyst::View::ByCode::Markup') };

#
# check if routines exist
#
can_ok('Catalyst::View::ByCode::Markup', 
       qw(new set_data open_tag close_tag add_tag
          add_comment add_cdata add_raw attr data as_text));

#
# check if object can get created
#
my $markup;
lives_ok {$markup = new Catalyst::View::ByCode::Markup} 'Markup Object creation 1';
is(ref($markup), 'Catalyst::View::ByCode::Markup', 'class name is Catalyst::View::ByCode::Markup');
is($markup->as_text(), '', 'empty markup is empty');

# raw text
lives_ok {$markup->add_raw('<!-- text & [] {} -->')} 'add raw things';
is($markup->as_text(), '<!-- text & [] {} -->', 'raw markup works');

# escaped text
lives_ok {$markup = new Catalyst::View::ByCode::Markup} 'Markup Object creation 2';
lives_ok {$markup->add_content('<!-- text & [] {} -->')} 'add escaped things';
is($markup->as_text(), '&#60;!-- text &#38; [] {} --&#62;', 'escaped markup works');

# simple empty tag
lives_ok {$markup = new Catalyst::View::ByCode::Markup} 'Markup Object creation 3';
lives_ok {$markup->add_tag('br')} 'add empty tag things';
like($markup->as_text(), qr{<br\s*/>}, 'add empty tag works');

# simple tag without content
lives_ok {$markup = new Catalyst::View::ByCode::Markup} 'Markup Object creation 4';
lives_ok {$markup->add_tag('div')} 'add simple tag w/o content';
like($markup->as_text(), qr{<div>\s*</div>}, 'add tag w/o content works');

# simple tag with attribute
lives_ok {$markup = new Catalyst::View::ByCode::Markup} 'Markup Object creation 5';
lives_ok {$markup->add_tag('div', {attribute => 'value'})} 'add tag w/ attribute';
like($markup->as_text(), qr{<div\s*attribute\s*=\s*"value"\s*>\s*</div>}, 'add tag w/ attribute works');

# simple tag with attribute and content
lives_ok {$markup = new Catalyst::View::ByCode::Markup} 'Markup Object creation 6';
lives_ok {$markup->add_tag('div', {attribute => 'value'}, 'simple content')} 'add tag w/ attr+content';
like($markup->as_text(), qr{<div\s*attribute\s*=\s*"value"\s*>\s*simple content\s*</div>}, 'add tag w/ attr+content works');

# simple tag with array-attribute and content
lives_ok {$markup = new Catalyst::View::ByCode::Markup} 'Markup Object creation 7';
lives_ok {$markup->add_tag('div', {attribute => ['value1','value2']}, 'simple content')} 'add tag w/ array-attr';
like($markup->as_text(), qr{<div\s*attribute\s*=\s*"value1 value2"\s*>\s*simple content\s*</div>}, 'add tag w/ array-attr works');

# simple tag with array-attribute (JavaScript) and content
lives_ok {$markup = new Catalyst::View::ByCode::Markup} 'Markup Object creation 8';
lives_ok {$markup->add_tag('div', {onclick => ['script1','script2']}, 'simple content')} 'add tag w/ js-attr';
like($markup->as_text(), qr{<div\s*onclick\s*=\s*"script1script2"\s*>\s*simple content\s*</div>}, 'add tag w/ js-attr works');

# nesting of tags and content with attributes
lives_ok {$markup = new Catalyst::View::ByCode::Markup} 'Markup Object creation 9';
lives_ok {$markup->open_tag('div')} 'open div tag';
lives_ok {$markup->attr({id => 'myId'})} 'add attribute';
lives_ok {$markup->add_content('content in ')} 'add content';
lives_ok {$markup->open_tag('b')} 'open b tag';
lives_ok {$markup->add_content('bold')} 'add content';
lives_ok {$markup->close_tag()} 'close b tag';
lives_ok {$markup->add_tag('hr')} 'add empty tag things';
lives_ok {$markup->close_tag()} 'close div tag';
like($markup->as_text(), qr{<div\s*id\s*=\s*"myId"\s*>\s*content in\s+<b>bold</b>\s*<hr\s*/>\s*</div>}, 'add complex things works');

### TODO: check references to subs, etc.
