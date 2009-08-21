use Test::More tests => 21;
use Test::Exception;
use Catalyst ();
use FindBin;
use Path::Class::File;

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
dies_ok {$subref = $view->_compile_template($c, 'erroneous_template.pl') } 'compilation dies';

lives_ok { $subref = $view->_compile_template($c, 'simple_template.pl') } 'compilation lives';
is(ref($subref), 'CODE', 'compile result is a CODEref');

is(${"Catalyst::Template::simple_template::_filename"}, "$FindBin::Bin/root/bycode/simple_template.pl", 'internal filename looks OK');
ok(${"Catalyst::Template::simple_template::_offset"}, 'internal offset is set');
ok(${"Catalyst::Template::simple_template::_mtime"}, 'internal mtime is set');
ok(${"Catalyst::Template::simple_template::_tempfile"}, 'internal tempfile is set');

ok('Catalyst::Template::simple_template'->can('RUN'), 'compiled package can run');
is($subref, 'Catalyst::Template::simple_template'->can('RUN'), 'RUN returned by compilation');

# see if template generates markup
### TODO
