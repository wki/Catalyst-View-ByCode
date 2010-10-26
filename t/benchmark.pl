#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";
use Catalyst::View::ByCode::Renderer ':markup';
use Benchmark ':all';

{
    package ByCodeTemplate;
    use Catalyst::View::ByCode::Renderer ':default';
    
    # define a template
    sub exec {
        table {
            tbody {
                for my $row (1..1000) {
                    trow {
                        for my $col (1..10) {
                            tcol { "$row:$col" };
                        }
                    };
                }
            };
        };
    }
}

{
    package TTTemplate;
    use Template;
    
    sub exec {
        my $output = '';
        my $code = q{
        <table>
            <tbody>
                [% FOREACH row IN [1..1000] %]
                <tr>
                    [% FOREACH col IN [1..10] %]
                    <td>[% row %]:[% col %]</td>
                    [% END %]
                </tr>
                [% END %]
            </tbody>
        </table>
        };
        
        my $template = Template->new({INTERPOLATE => 1});
        $template->process(\$code, {}, \$output)
            or die $template->error;
        return $output;
    }
}

# print TTTemplate::exec(); exit;

# init_markup();
# MyTemplate::exec();

my $results = timethese(10, {
    bycode => sub { init_markup(); ByCodeTemplate::exec(); },
    tt     => sub { TTTemplate::exec(); },
});
cmpthese($results);
