# -*- perl -*-
use Test::More no_plan;
use Test::Exception;

#
# can module get use'd ?
#
BEGIN { use_ok('Catalyst::View::ByCode::Util') };

#
# test clean_path
#
can_ok('main', 'make_hashref');
can_ok('main', 'clean_path');
can_ok('main', 'encode_64');
can_ok('main', 'decode_64');
can_ok('main', 'find_sub_in_callers');

#
# test make_hashref
#
is_deeply(make_hashref(a => 42, b => 47), {a => 42, b => 47},  'hash from list');
is_deeply(make_hashref({a => 42, b => 47}), {a => 42, b => 47},'hash from hashref');
is_deeply(make_hashref([a => 42, b => 47]), {a => 42, b => 47},'hash from arrayref');

#
# test base64 en/decoding
#
my $decoded = {a => 42, s => 'string', b => 1, ar => [1,2,3]};
my $encoded = encode_64( $decoded );

ok($encoded =~ m{\A [-0-9a-zA-Z*]+ \z}xms, 'right characters in use');
is_deeply(decode_64($encoded), $decoded, 'decoding is OK');

#
# test clean_path
#
is(clean_path(''), '', 'empty string stays same');
is(clean_path('/'), '/', 'root dir stays same');
is(clean_path('//'), '/', 'root dir stays same2');
is(clean_path('///'), '/', 'root dir stays same3');
is(clean_path('////'), '/', 'root dir stays same4');
is(clean_path('/xxx'), '/xxx', 'xxx dir stays same');
is(clean_path('//xxx'), '/xxx', 'xxx dir stays same2');
is(clean_path('///xxx'), '/xxx', 'xxx dir stays same3');
is(clean_path('////xxx'), '/xxx', 'xxx dir stays same4');
is(clean_path('/xxx/'), '/xxx', 'xxx dir stays same');
is(clean_path('//xxx/'), '/xxx', 'xxx dir stays same2');
is(clean_path('///xxx/'), '/xxx', 'xxx dir stays same3');
is(clean_path('////xxx/'), '/xxx', 'xxx dir stays same4');
is(clean_path('/xxx//'), '/xxx', 'xxx dir stays same');
is(clean_path('//xxx//'), '/xxx', 'xxx dir stays same2');
is(clean_path('///xxx//'), '/xxx', 'xxx dir stays same3');
is(clean_path('////xxx//'), '/xxx', 'xxx dir stays same4');
