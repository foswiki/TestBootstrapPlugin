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

sub _workOutOS {
    unless ( ( $boot_cfg{DetailedOS} = $^O ) ) {
        require Config;
        $boot_cfg{DetailedOS} = $Config::Config{'osname'};
    }
    $boot_cfg{OS} = 'UNIX';
    if ( $boot_cfg{DetailedOS} =~ /darwin/i ) {    # MacOS X
        $boot_cfg{OS} = 'UNIX';
    }
    elsif ( $boot_cfg{DetailedOS} =~ /Win/i ) {
        $boot_cfg{OS} = 'WINDOWS';
    }
    elsif ( $boot_cfg{DetailedOS} =~ /vms/i ) {
        $boot_cfg{OS} = 'VMS';
    }
    elsif ( $boot_cfg{DetailedOS} =~ /bsdos/i ) {
        $boot_cfg{OS} = 'UNIX';
    }
    elsif ( $boot_cfg{DetailedOS} =~ /dos/i ) {
        $boot_cfg{OS} = 'DOS';
    }
    elsif ( $boot_cfg{DetailedOS} =~ /^MacOS$/i ) {    # MacOS 9 or earlier
        $boot_cfg{OS} = 'MACINTOSH';
    }
    elsif ( $boot_cfg{DetailedOS} =~ /os2/i ) {
        $boot_cfg{OS} = 'OS2';
    }
}

sub _BOOTSTRAP {
    my ( $session, $params, $topic, $web, $topicObject ) = @_;

    my $msg = "<blockquote><verbatim>\n";

    # Try to repair $boot_cfg to a minimal configuration,
    # using paths and URLs relative to this request. If URL
    # rewriting is happening in the web server this is likely
    # to go down in flames, but it gives us the best chance of
    # recovering. We need to guess values for all the vars that
    # would otherwise default to NOT SET.
    eval "require FindBin";
    return "Could not load FindBin to support configuration recovery: $@"
      if $@;
    FindBin::again();    # in case we are under mod_perl or similar
    $FindBin::Bin =~ /^(.*)$/;
    my $bin = $1;
    $FindBin::Script =~ /^(.*)$/;
    my $script = $1;
    $msg .=
      "AUTOCONFIG: Found Bin dir: $bin, Script name: $script using FindBin\n"
      if (TRAUTO);

    $boot_cfg{ScriptSuffix} = ( fileparse( $script, qr/\.[^.]*/ ) )[2];
    print STDERR "AUTOCONFIG: Found SCRIPT SUFFIX $boot_cfg{ScriptSuffix} \n"
      if ( TRAUTO && $boot_cfg{ScriptSuffix} );

    my $protocol = $ENV{HTTPS} ? 'https' : 'http';
    if ( $ENV{HTTP_HOST} ) {
        $boot_cfg{DefaultUrlHost} = "$protocol://$ENV{HTTP_HOST}";
        $msg .=
"AUTOCONFIG: Set DefaultUrlHost $boot_cfg{DefaultUrlHost} from HTTP_HOST $ENV{HTTP_HOST} \n"
          if (TRAUTO);
    }
    elsif ( $ENV{SERVER_NAME} ) {
        $boot_cfg{DefaultUrlHost} = "$protocol://$ENV{SERVER_NAME}";
        $msg .=
"AUTOCONFIG: Set DefaultUrlHost $boot_cfg{DefaultUrlHost} from SERVER_NAME $ENV{SERVER_NAME} \n"
          if (TRAUTO);
    }
    else {
        # OK, so this is barfilicious. Think of something better.
        $boot_cfg{DefaultUrlHost} = "$protocol://localhost";
        $msg .=
"AUTOCONFIG: barfilicious: Set DefaultUrlHost $boot_cfg{DefaultUrlHost} \n"
          if (TRAUTO);
    }

    # Examine the CGI path.   The 'view' script it typically removed from the
    # URL when using "Short URLs.  If this BEGIN block is being run by
    # 'view',  then $boot_cfg{ScriptUrlPaths}{view} will be correctly
    # bootstrapped.   If run for any other script, it will be set to a
    # reasonable though probably incorrect default.
    if ( $ENV{SCRIPT_NAME} ) {
        $msg .= "AUTOCONFIG: Found SCRIPT $ENV{SCRIPT_NAME} \n"
          if (TRAUTO);

        if ( $ENV{SCRIPT_NAME} =~ m{^(.*?)/$script(\b|$)} ) {

            # Conventional URLs   with path and script
            $boot_cfg{ScriptUrlPath} = $1;
            $boot_cfg{ScriptUrlPaths}{view} =
              $1 . '/view' . $boot_cfg{ScriptSuffix};

            # This might not work, depending on the websrver config,
            # but it's the best we can do
            $boot_cfg{PubUrlPath} = "$1/../pub";
        }
        else {
            # Short URLs but with a path
            $msg .= "AUTOCONFIG: Found path, but no script. short URLs \n"
              if (TRAUTO);
            $boot_cfg{ScriptUrlPath}        = $ENV{SCRIPT_NAME} . '/bin';
            $boot_cfg{ScriptUrlPaths}{view} = $ENV{SCRIPT_NAME};
            $boot_cfg{PubUrlPath}           = $ENV{SCRIPT_NAME} . '/pub';
        }
    }
    else {
        #  No script, no path,  shortest URLs
        $msg .= "AUTOCONFIG: No path, No script, probably shorter URLs \n"
          if (TRAUTO);
        $boot_cfg{ScriptUrlPaths}{view} = '';
        $boot_cfg{ScriptUrlPath}        = '/bin';
        $boot_cfg{PubUrlPath}           = '/pub';
    }

    $msg .= "AUTOCONFIG: Using ScriptUrlPath $boot_cfg{ScriptUrlPath} \n"
      if (TRAUTO);
    $msg .= "AUTOCONFIG: Using {ScriptUrlPaths}{view} "
      . (
        ( defined $boot_cfg{ScriptUrlPaths}{view} )
        ? $boot_cfg{ScriptUrlPaths}{view}
        : 'undef'
      )
      . "\n"
      if (TRAUTO);
    $msg .= "AUTOCONFIG: Using PubUrlPath: $boot_cfg{PubUrlPath} \n"
      if (TRAUTO);

    my %rel_to_root = (
        DataDir    => { dir => 'data',   required => 0 },
        LocalesDir => { dir => 'locale', required => 0 },
        PubDir     => { dir => 'pub',    required => 0 },
        ToolsDir   => { dir => 'tools',  required => 0 },
        WorkingDir => {
            dir           => 'working',
            required      => 1,
            validate_file => 'README'
        },
        TemplateDir => {
            dir           => 'templates',
            required      => 1,
            validate_file => 'configure.tmpl'
        },
        ScriptDir => {
            dir           => 'bin',
            required      => 1,
            validate_file => 'setlib.cfg'
        }
    );

    # Note that we don't resolve x/../y to y, as this might
    # confuse soft links
    my $root = File::Spec->catdir( $bin, File::Spec->updir() );
    $root =~ s{\\}{/}g;
    my $fatal = '';
    my $warn  = '';
    while ( my ( $key, $def ) = each %rel_to_root ) {
        $boot_cfg{$key} = File::Spec->rel2abs( $def->{dir}, $root );
        $boot_cfg{$key} = abs_path( $boot_cfg{$key} );
        ( $boot_cfg{$key} ) = $boot_cfg{$key} =~ m/^(.*)$/;    # untaint

        $msg .= "AUTOCONFIG: $key = $boot_cfg{$key} \n"
          if (TRAUTO);

        if ( -d $boot_cfg{$key} ) {
            if ( $def->{validate_file}
                && !-e "$boot_cfg{$key}/$def->{validate_file}" )
            {
                $fatal .=
"\n{$key} (guessed $boot_cfg{$key}) $boot_cfg{$key}/$def->{validate_file} not found";
            }
        }
        elsif ( $def->{required} ) {
            $fatal .= "\n{$key} (guessed $boot_cfg{$key})";
        }
        else {
            $warn .= "\n{$key} could not be guessed";
        }
    }
    if ($fatal) {
        $msg .= <<EPITAPH;
Unable to bootstrap configuration. LocalSite.cfg could not be loaded,
and Foswiki was unable to guess the locations of the following critical
directories: $fatal
EPITAPH
    }

    _workOutOS();

    $boot_cfg{isVALID}         = 1;
    $boot_cfg{isBOOTSTRAPPING} = 1;

    # Note: message is not I18N'd because there is no point; there
    # is no localisation in a default cfg derived from Foswiki.spec
    $msg .= <<BOOTS;

 *WARNING !LocalSite.cfg could not be found, or failed to load.* This
Foswiki is running using a bootstrap configuration worked
out by detecting the layout of the installation. Any requests made to this
Foswiki will be treated as requests made by an administrator with full rights
to make changes! You should either:
   * correct any permissions problems with an existing !LocalSite.cfg (see the webserver error logs for details), or
   * visit [[%SCRIPTURL{configure}%?VIEWPATH=$boot_cfg{ScriptUrlPaths}{view}][configure]] as soon as possible to generate a new one.

BOOTS

    require Data::Dumper;

    #$msg .= Data::Dumper::Dumper( \%boot_cfg );

    $msg .= "</verbatim>\n";
    $msg .= "<noautolink>\n";
    $msg .= "| *Key* | *Current* | *Bootstrap* |\n";

    foreach my $key ( sort keys %boot_cfg ) {

        # SMELL: Not very pretty
        if ( ref( $boot_cfg{$key} ) eq 'HASH' ) {
            foreach my $k2 ( keys %{ $boot_cfg{$key} } ) {
                my $cur =
                  ( defined $Foswiki::cfg{$key}{$k2} )
                  ? $Foswiki::cfg{$key}{$k2}
                  : '(undefined)';
                $cur =
                  ( length $Foswiki::cfg{$key}{$k2} )
                  ? $Foswiki::cfg{$key}{$k2}
                  : '(empty)';
                my $boot =
                  ( defined $boot_cfg{$key}{$k2} )
                  ? $boot_cfg{$key}{$k2}
                  : '(undefined)';
                $boot =
                  ( length $boot_cfg{$key}{$k2} )
                  ? $boot_cfg{$key}{$k2}
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
              ( defined $boot_cfg{$key} ) ? $boot_cfg{$key} : '(undefined)';
            $boot = ( length $boot_cfg{$key} ) ? $boot_cfg{$key} : '(empty)';
            $msg .= "| =$key= | =$cur= | =$boot= |\n";
        }
    }
    return "$msg</noautolink></blockquote>\n";

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
