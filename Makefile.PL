use inc::Module::Install;

name     'Catalyst-View-ByCode';
all_from 'lib/Catalyst/View/ByCode.pm';
author   q{Wolfgang Kinkeldei <wolfgang@kinkeldei.de>};
license  'perl';
perl_version '5.8.0';

requires 'Catalyst::Runtime'        => '5.80';
requires 'Devel::Declare'           => '0.005007';
requires 'HTML::Entities'           => '1.35';
requires 'HTML::Tagset'             => '3.10';
requires 'List::Util'               => '1.21';
requires 'MIME::Base64'             => '3.07';
requires 'Moose';
requires 'MooseX::AttributeHelpers' => '0.23'; # 0.22 fails
requires 'Test::Builder'            => '0.86';
requires 'Test::Builder::Tester'    => '1.18';
requires 'Test::Harness'            => '3.14';
requires 'Test::More'               => '0.86';
requires 'UUID::Random'             => '0.04';
requires 'YAML'                     => '0.68';

test_requires 'Test::More';
test_requires 'Test::Exception';
test_requires 'Catalyst::Test';

auto_install;

WriteAll;
