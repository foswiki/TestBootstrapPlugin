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

our $VERSION = '1.1';

our $RELEASE = '09 Sep 2016';

# One line description of the module
our $SHORTDESCRIPTION = 'Test foswiki bootstrap code';

our $NO_PREFS_IN_TOPIC = 1;

our %boot_cfg;

my @BOOTSTRAP =
  qw( {DataDir} {DefaultUrlHost} {DetailedOS} {OS} {PubUrlPath} {ToolsDir} {WorkingDir}
  {PubDir} {TemplateDir} {ScriptDir} {ScriptUrlPath} {ScriptUrlPaths}{view}
  {ScriptSuffix} {LocalesDir} {Store}{Implementation}
  {Store}{SearchAlgorithm} );

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
    }

    $msg .= "\n\n";

    #$Data::Dumper::Sortkeys = 1;
    #$Data::Dumper::Varname = 'ENV';
    #$msg .= Data::Dumper::Dumper( \%ENV );

    $msg .= "</verbatim>\n\n<noautolink>\n";
    $msg .= "| *Key* | *Current* | *Bootstrap* |\n";

    foreach my $key ( sort @BOOTSTRAP ) {
        my $cur;
        my $bs;

        print STDERR "\$cur=\$Foswiki::cfg$key=~/^(.*)\$/\n";

        eval("\$cur=\$Foswiki::cfg$key");
        print STDERR "CUR=" . ( defined $cur ? $cur : 'undef' ) . "\n";
        eval("\$bs=\$boot_cfg->$key");

        $cur = '(undefined)' unless defined $cur;
        $cur = '(empty)'     unless length $cur;
        $bs  = '(undefined)' unless defined $bs;
        $bs  = '(empty)'     unless length $bs;
        my $eq = ( $cur ne $bs ) ? '==' : '=';
        $msg .= "| $eq$key$eq | $eq$cur$eq | $eq$bs$eq |\n";
    }

    return "$msg</noautolink></blockquote>\n";

}

sub _runBootstrap {
    local %Foswiki::cfg = ( Engine => $Foswiki::cfg{Engine} );
    require Foswiki::Plugins::TestBootstrapPlugin::Bootstrap;
    my $msg =
      Foswiki::Plugins::TestBootstrapPlugin::Bootstrap::bootstrapConfig();
    $msg .=
      Foswiki::Plugins::TestBootstrapPlugin::Bootstrap::bootstrapWebSettings(
        'view');

    return ( \%Foswiki::cfg, $msg );
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
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
