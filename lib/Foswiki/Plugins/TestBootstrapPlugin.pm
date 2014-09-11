# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Plugins::TestBootstrapPlugin


=cut

package Foswiki::Plugins::TestBootstrapPlugin;

# Always use strict to enforce variable scoping
use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version
use Cwd qw( abs_path );
use File::Basename;

use constant TRAUTO => 1;

our $VERSION = '1.0';

our $RELEASE = '04 Sep 2014';

# One line description of the module
our $SHORTDESCRIPTION = 'Test foswiki bootstrap code';

our $NO_PREFS_IN_TOPIC = 1;

our %boot_cfg;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    Foswiki::Func::registerTagHandler( 'BOOTSTRAP', \&_BOOTSTRAP )
      if ( Foswiki::Func::isAnAdmin() );

    # Plugin correctly initialized
    return 1;
}

sub _BOOTSTRAP {
    my ( $session, $params, $topic, $web, $topicObject ) = @_;

    my $msg = "<blockquote><verbatim>\n";
    my $boot_cfg;
    my $resp;

    {
        local *STDERR;
        my $log;
        open STDERR, '>', \$log;

        ( $boot_cfg, $resp ) = _runBootstrap();
        close STDERR;
        $msg .= $resp . "\n\n";
        $msg .= $log;
        $msg .= "</verbatim><noautolink>\n";
    }
    $msg .= "| *Key* | *Current* | *Bootstrap* |\n";

    foreach my $key ( sort keys %$boot_cfg ) {
        next if ( $key eq 'BOOTSTRAP' );

        # SMELL: Not very pretty
        if ( ref( $boot_cfg->{$key} ) eq 'HASH' ) {
            foreach my $k2 ( keys %{ $boot_cfg->{$key} } ) {
                my $cur =
                  ( defined $Foswiki::cfg{$key}{$k2} )
                  ? $Foswiki::cfg{$key}{$k2}
                  : '(undefined)';
                $cur =
                  ( length $Foswiki::cfg{$key}{$k2} )
                  ? $Foswiki::cfg{$key}{$k2}
                  : '(empty)';
                my $boot =
                  ( defined $boot_cfg->{$key}{$k2} )
                  ? $boot_cfg->{$key}{$k2}
                  : '(undefined)';
                $boot =
                  ( length $boot_cfg->{$key}{$k2} )
                  ? $boot_cfg->{$key}{$k2}
                  : '(empty)';
                $msg .= "| ={$key}{$k2}= | =$cur= | =$boot= |\n";
            }
            next;
        }
        else {
            my $cur =
              ( defined $Foswiki::cfg{$key} )
              ? $Foswiki::cfg{$key}
              : '(undefined)';
            $cur =
              ( length $Foswiki::cfg{$key} ) ? $Foswiki::cfg{$key} : '(empty)';
            my $boot =
              ( defined $boot_cfg->{$key} ) ? $boot_cfg->{$key} : '(undefined)';
            $boot =
              ( length $boot_cfg->{$key} ) ? $boot_cfg->{$key} : '(empty)';
            $msg .= "| =$key= | =$cur= | =$boot= |\n";
        }
    }

    return "$msg</noautolink></blockquote>\n";

}

sub _runBootstrap {
    local %Foswiki::cfg = ( Engine => $Foswiki::cfg{Engine} );
    my $msg = Foswiki::Configure::Load::bootstrapConfig(1);

    #my %boot_cfg = %Foswiki::cfg;
    return ( \%Foswiki::cfg, $msg );
}
1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
