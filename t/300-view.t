# -*- perl -*-
use Test::More;
use Test::Exception;
use Catalyst ();
use FindBin;
use lib "$FindBin::Bin/lib";
use Path::Class;

# setup our Catalyst :-)
my $c = Catalyst->new();
$c->setup_log();
$c->setup_home("$FindBin::Bin");

# can we use it?
use_ok 'Catalyst::View::ByCode';

# check for methods
can_ok('Catalyst::View::ByCode' => qw(extension root_dir wrapper include process));

# instantiate
my $view;
lives_ok { $view = $c->setup_component('Catalyst::View::ByCode') } 'setup view worked';
isa_ok($view, 'Catalyst::View::ByCode', 'view class looks good');

### test only ::: is($view->_application->path_to('root'), 'adsf', 'bla');
# check default attributes
is($view->extension, '.pl', 'extension looks good');
is($view->root_dir,  'root/bycode', 'root_dir looks good');
is($view->wrapper,   'wrapper.pl', 'extension looks good');
is_deeply($view->include,   [], 'includes look good');

#
# some low-level checks
#
is($view->_find_template($c, 'simple_template.pl'), 'simple_template.pl', 'find simple_template with extension');
is($view->_find_template($c, 'simple_template'), 'simple_template.pl', 'find simple_template without extension');

is($view->_template_to_package($c, 'simple_template.pl'), 'Catalyst::Template::simple_template', 'package name looks good 1');
is($view->_template_to_package($c, 'simple_template'), 'Catalyst::Template::simple_template', 'package name looks good 2');

#
# test compilation
#
my $subref;
lives_ok {$subref = $view->_compile_template($c, 'erroneous_template.pl') } 'compilation 1 lives';
ok(!$subref, 'result of compilation is not a subref');

lives_ok { $subref = $view->_compile_template($c, 'simple_template.pl') } 'compilation lives';
is(ref($subref), 'CODE', 'compile result is a CODEref');

is(${"Catalyst::Template::simple_template::_filename"}, file("$FindBin::Bin", qw(root bycode simple_template.pl)), 'internal filename looks OK');
ok(${"Catalyst::Template::simple_template::_offset"}, 'internal offset is set');
ok(${"Catalyst::Template::simple_template::_mtime"}, 'internal mtime is set');
ok(${"Catalyst::Template::simple_template::_tempfile"}, 'internal tempfile is set');

ok('Catalyst::Template::simple_template'->can('RUN'), 'compiled package can run');
is($subref, 'Catalyst::Template::simple_template'->can('RUN'), 'RUN returned by compilation');

# see if template generates markup
lives_ok {Catalyst::View::ByCode::Renderer::init_markup()} 'initing simple markup lives';
lives_ok {$subref->()} 'calling simple_template lives';
like(Catalyst::View::ByCode::Renderer::get_markup(), 
     qr{\s*
        <div\s+id="main">\s*Perl\s+rocks\s*</div>\s*
        \s*}xms, 
     'simple markup looks OK');

#
# test block inside a template
#
$subref = 1234;
lives_ok {$subref = $view->_compile_template($c, 'block_template.pl')} 'compilation block lives';
is(ref($subref), 'CODE', 'compile block result is a CODEref');

lives_ok {Catalyst::View::ByCode::Renderer::init_markup()} 'initing block markup lives';
lives_ok {$subref->()} 'calling block_template lives';
like(Catalyst::View::ByCode::Renderer::get_markup(), 
     qr{\s*
        <b>\s*before\s+block\s*</b>
        \s*
        <div\s+id="sillyblock">\s*just\s+my\s+2\s+centOK:\s+1\s*</div>\s*
        \s*
        <b>\s*after\s+block\s*</b>
        \s*}xms, 
     'block markup looks OK');

#
# test including a package that defines a block
#
$subref = 999;

use_ok 'IncludeMe';

lives_ok {Catalyst::View::ByCode::Renderer::init_markup()} 'initing block markup lives';
lives_ok { $view->include(['IncludeMe']) } 'setting include lives';
lives_ok {$subref = $view->_compile_template($c, 'including_template.pl')} 'compilation including template lives';

### tests fail starting here. reason: import does not work as expected...
is(ref($subref), 'CODE', 'compile including result is a CODEref');
lives_ok {$subref->()} 'calling block_template lives';
like(Catalyst::View::ByCode::Renderer::get_markup(), 
     qr{<div \s+ id="includable_block">\s*i\s+am\s+included.*</div>}xms, 'including markup looks good');

#
# test a template acting as a wrapper
#
$c->stash->{yield}->{content} = 'simple_template.pl';
$subref = 0;
lives_ok {$view->init_markup($c)} 'initing block markup lives';
lives_ok {$subref = $view->_compile_template($c, 'wrap_template.pl')} 'compilation wrapping template lives';
is(ref($subref), 'CODE', 'compile wrapping result is a CODEref');
lives_ok {$subref->()} 'calling wrap_template lives';
like(Catalyst::View::ByCode::Renderer::get_markup(), 
     qr{<body>\s*<div\s+id="main">\s*Perl\s+rocks\s*</div>\s*</body>}xms, 'including markup looks good');

### TODO: test more kinds of 'yield()' usage.

done_testing();
