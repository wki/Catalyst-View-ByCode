package UniApp;

use Moose;
extends 'Catalyst';

use Catalyst::Runtime '5.90040'; # unicode plugin is included since then
use FindBin;

use Catalyst; # ( qw(-Log=error) );

__PACKAGE__->config(
    name           => 'UniApp',
    encoding       => 'UTF-8',
    default_view   => 'ByCode',
    home           => "$FindBin::Bin",
    'View::ByCode' => { 
        wrapper => 'wrap_template.pl', 
    },
);

__PACKAGE__->setup();

1;
