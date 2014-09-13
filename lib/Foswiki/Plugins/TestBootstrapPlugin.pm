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

my @BOOTSTRAP =
  qw( {DataDir} {DefaultUrlHost} {PubUrlPath} {ToolsDir} {WorkingDir}
  {PubDir} {TemplateDir} {ScriptDir} {ScriptUrlPath} {ScriptUrlPaths}{view} {ScriptSuffix} {LocalesDir} );

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
    my $msg;

    if ( Foswiki::Configure::Load->can('bootstrapConfig') ) {
        $msg = Foswiki::Configure::Load::bootstrapConfig(1);
    }
    else {
        $msg = _bootstrapConfig(1);
    }

    return ( \%Foswiki::cfg, $msg );
}

=begin TML

---++ StaticMethod bootstrapConfig()

This routine is a copy of the bootstrapConfig() that is shipped with version 1.2
Foswiki::Configure::Load.  It is included here so that this plugin can also be used on a 1.1 system.

When syncing over an updated version from Foswiki.pm:
   * Delete the code that dies if ConfigurePlugin is not installed
   * Also pull in _workOutOS if that has changed.
   * Change the filename used to validate templates from configure.tmpl to foswiki.tmpl

=cut

sub _bootstrapConfig {
    my $noload = shift;

    # Failed to read LocalSite.cfg
    # Clear out $Foswiki::cfg to allow variable expansion to work
    # when reloading Foswiki.spec et al.
    # SMELL: have to keep {Engine} as this is defined by the
    # script (smells of a hack).
    %Foswiki::cfg = ( Engine => $Foswiki::cfg{Engine} );

    # Try to repair $Foswiki::cfg to a minimal configuration,
    # using paths and URLs relative to this request. If URL
    # rewriting is happening in the web server this is likely
    # to go down in flames, but it gives us the best chance of
    # recovering. We need to guess values for all the vars that
    # woudl trigger "undefined" errors
    eval "require FindBin";
    die "Could not load FindBin to support configuration recovery: $@"
      if $@;
    FindBin::again();    # in case we are under mod_perl or similar
    $FindBin::Bin =~ /^(.*)$/;
    my $bin = $1;
    $FindBin::Script =~ /^(.*)$/;
    my $script = $1;
    print STDERR
      "AUTOCONFIG: Found Bin dir: $bin, Script name: $script using FindBin\n"
      if (TRAUTO);

    $Foswiki::cfg{ScriptSuffix} = ( fileparse( $script, qr/\.[^.]*/ ) )[2];
    print STDERR
      "AUTOCONFIG: Found SCRIPT SUFFIX $Foswiki::cfg{ScriptSuffix} \n"
      if ( TRAUTO && $Foswiki::cfg{ScriptSuffix} );

    my $protocol = $ENV{HTTPS} ? 'https' : 'http';
    if ( $ENV{HTTP_HOST} ) {
        $Foswiki::cfg{DefaultUrlHost} = "$protocol://$ENV{HTTP_HOST}";
        print STDERR
"AUTOCONFIG: Set DefaultUrlHost $Foswiki::cfg{DefaultUrlHost} from HTTP_HOST $ENV{HTTP_HOST} \n"
          if (TRAUTO);
    }
    elsif ( $ENV{SERVER_NAME} ) {
        $Foswiki::cfg{DefaultUrlHost} = "$protocol://$ENV{SERVER_NAME}";
        print STDERR
"AUTOCONFIG: Set DefaultUrlHost $Foswiki::cfg{DefaultUrlHost} from SERVER_NAME $ENV{SERVER_NAME} \n"
          if (TRAUTO);
    }
    else {
        # OK, so this is barfilicious. Think of something better.
        $Foswiki::cfg{DefaultUrlHost} = "$protocol://localhost";
        print STDERR
"AUTOCONFIG: barfilicious: Set DefaultUrlHost $Foswiki::cfg{DefaultUrlHost} \n"
          if (TRAUTO);
    }

# Examine the CGI path.   The 'view' script it typically removed from the
# URL when using "Short URLs.  If this BEGIN block is being run by
# 'view',  then $Foswiki::cfg{ScriptUrlPaths}{view} will be correctly
# bootstrapped.   If run for any other script, it will be set to a
# reasonable though probably incorrect default.
#
# In order to recover the correct view path when the script is 'configure',
# the ConfigurePlugin stashes the path to the view script into a session variable.
# and then recovers it.  When the jsonrpc script is called to save the configuration
# it then has the VIEWPATH parameter available.  If "view" was never called during
# configuration, then it will not be set correctly.
    if ( $ENV{SCRIPT_NAME} ) {
        print STDERR "AUTOCONFIG: Found SCRIPT $ENV{SCRIPT_NAME} \n"
          if (TRAUTO);

        if ( $ENV{SCRIPT_NAME} =~ m{^(.*?)/$script(\b|$)} ) {

            # Conventional URLs   with path and script
            $Foswiki::cfg{ScriptUrlPath} = $1;
            $Foswiki::cfg{ScriptUrlPaths}{view} =
              $1 . '/view' . $Foswiki::cfg{ScriptSuffix};

            # This might not work, depending on the websrver config,
            # but it's the best we can do
            $Foswiki::cfg{PubUrlPath} = "$1/../pub";
        }
        else {
            # Short URLs but with a path
            print STDERR "AUTOCONFIG: Found path, but no script. short URLs \n"
              if (TRAUTO);
            $Foswiki::cfg{ScriptUrlPath}        = $ENV{SCRIPT_NAME} . '/bin';
            $Foswiki::cfg{ScriptUrlPaths}{view} = $ENV{SCRIPT_NAME};
            $Foswiki::cfg{PubUrlPath}           = $ENV{SCRIPT_NAME} . '/pub';
        }
    }
    else {
        #  No script, no path,  shortest URLs
        print STDERR "AUTOCONFIG: No path, No script, probably shorter URLs \n"
          if (TRAUTO);
        $Foswiki::cfg{ScriptUrlPaths}{view} = '';
        $Foswiki::cfg{ScriptUrlPath}        = '/bin';
        $Foswiki::cfg{PubUrlPath}           = '/pub';
    }

    if (TRAUTO) {
        print STDERR
          "AUTOCONFIG: Using ScriptUrlPath $Foswiki::cfg{ScriptUrlPath} \n";
        print STDERR "AUTOCONFIG: Using {ScriptUrlPaths}{view} "
          . (
            ( defined $Foswiki::cfg{ScriptUrlPaths}{view} )
            ? $Foswiki::cfg{ScriptUrlPaths}{view}
            : 'undef'
          ) . "\n";
        print STDERR
          "AUTOCONFIG: Using PubUrlPath: $Foswiki::cfg{PubUrlPath} \n";
    }

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
            validate_file => 'foswiki.tmpl'
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
        $Foswiki::cfg{$key} = File::Spec->rel2abs( $def->{dir}, $root );
        $Foswiki::cfg{$key} = abs_path( $Foswiki::cfg{$key} );
        ( $Foswiki::cfg{$key} ) = $Foswiki::cfg{$key} =~ m/^(.*)$/;    # untaint

        print STDERR "AUTOCONFIG: $key = $Foswiki::cfg{$key} \n"
          if (TRAUTO);

        if ( -d $Foswiki::cfg{$key} ) {
            if ( $def->{validate_file}
                && !-e "$Foswiki::cfg{$key}/$def->{validate_file}" )
            {
                $fatal .=
"\n{$key} (guessed $Foswiki::cfg{$key}) $Foswiki::cfg{$key}/$def->{validate_file} not found";
            }
        }
        elsif ( $def->{required} ) {
            $fatal .= "\n{$key} (guessed $Foswiki::cfg{$key})";
        }
        else {
            $warn .=
              "\n      * Note: {$key} could not be guessed. Set it manually!";
        }
    }
    if ($fatal) {
        die <<EPITAPH;
Unable to bootstrap configuration. LocalSite.cfg could not be loaded,
and Foswiki was unable to guess the locations of the following critical
directories: $fatal
EPITAPH
    }

    # Re-read Foswiki.spec *and Config.spec*. We need the Config.spec's
    # to get a true picture of our defaults (notably those from
    # JQueryPlugin. Without the Config.spec, no plugins get registered)
    Foswiki::Configure::Load::readConfig( 0, 0, 1 ) unless ($noload);

    _workOutOS();

    $Foswiki::cfg{isVALID}         = 1;
    $Foswiki::cfg{isBOOTSTRAPPING} = 1;
    push( @{ $Foswiki::cfg{BOOTSTRAP} }, @BOOTSTRAP );

    # Note: message is not I18N'd because there is no point; there
    # is no localisation in a default cfg derived from Foswiki.spec
    my $system_message = <<BOOTS;
 *WARNING !LocalSite.cfg could not be found, or failed to load.* %BR%This
Foswiki is running using a bootstrap configuration worked
out by detecting the layout of the installation. Any requests made to this
Foswiki will be treated as requests made by an administrator with full rights
to make changes! You should either:
   * correct any permissions problems with an existing !LocalSite.cfg (see the webserver error logs for details), or
   * visit [[%SCRIPTURL{configure}%?VIEWPATH=$Foswiki::cfg{ScriptUrlPaths}{view}][configure]] as soon as possible to generate a new one.
BOOTS

    if ($warn) {
        chomp $system_message;
        $system_message .= $warn . "\n";
    }
    return ( $system_message || '' );

}

sub _workOutOS {
    unless ( ( $Foswiki::cfg{DetailedOS} = $^O ) ) {
        require Config;
        $Foswiki::cfg{DetailedOS} = $Config::Config{'osname'};
    }
    $Foswiki::cfg{OS} = 'UNIX';
    if ( $Foswiki::cfg{DetailedOS} =~ /darwin/i ) {    # MacOS X
        $Foswiki::cfg{OS} = 'UNIX';
    }
    elsif ( $Foswiki::cfg{DetailedOS} =~ /Win/i ) {
        $Foswiki::cfg{OS} = 'WINDOWS';
    }
    elsif ( $Foswiki::cfg{DetailedOS} =~ /vms/i ) {
        $Foswiki::cfg{OS} = 'VMS';
    }
    elsif ( $Foswiki::cfg{DetailedOS} =~ /bsdos/i ) {
        $Foswiki::cfg{OS} = 'UNIX';
    }
    elsif ( $Foswiki::cfg{DetailedOS} =~ /dos/i ) {
        $Foswiki::cfg{OS} = 'DOS';
    }
    elsif ( $Foswiki::cfg{DetailedOS} =~ /^MacOS$/i ) {    # MacOS 9 or earlier
        $Foswiki::cfg{OS} = 'MACINTOSH';
    }
    elsif ( $Foswiki::cfg{DetailedOS} =~ /os2/i ) {
        $Foswiki::cfg{OS} = 'OS2';
    }
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
