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
  {PubDir} {TemplateDir} {ScriptDir} {ScriptUrlPath} {ScriptUrlPaths}{view}
  {ScriptSuffix} {LocalesDir} {Store}{Implementation}
  {Store}{SearchAlgorithm} {_grepProgram} );

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
    foreach my $ek ( sort keys %ENV ) {
        $msg .= "\$ENV{$ek} = $ENV{$ek} \n";
    }

    $msg .= "</verbatim>\n\n<noautolink>\n";
    $msg .= "| *Key* | *Current* | *Bootstrap* |\n";

    foreach my $key ( sort @BOOTSTRAP ) {
        my $cur;
        my $bs;

        print STDERR "\$cur=\$Foswiki::cfg$key=~/^(.*)\$/\n";

        eval("\$cur=\$Foswiki::cfg$key");
        print STDERR "CUR=$cur\n";
        eval("\$bs=\$boot_cfg->$key");

        $cur = '(undefined)' unless defined $cur;
        $cur = '(empty)'     unless length $cur;
        $bs  = '(undefined)' unless defined $bs;
        $bs  = '(empty)'     unless length $bs;
        $msg .= "| =$key= | =$cur= | =$bs= |\n";
    }

    return "$msg</noautolink></blockquote>\n";

}

sub _runBootstrap {
    local %Foswiki::cfg = ( Engine => $Foswiki::cfg{Engine} );
    my $msg;

    if ( Foswiki::Configure::Load->can('bootstrapConfig') ) {
        $msg = Foswiki::Configure::Load::bootstrapConfig();
    }
    else {
        $msg = bootstrapConfig();
    }

    return ( \%Foswiki::cfg, $msg );
}

#================ CUT / PASTE from Foswiki::Configure::Load =====================
# After pasting in this code from Load.pm, be sure to comment out the line
#   Foswiki::Configure::Load::readConfig( 0, 0, 1, 1);
# found below.  Foswiki 1.1 does not have the 4th parameter (noLocal).
#

=begin TML

---++ StaticMethod setBootstrap()

This routine is called to initialize the bootstrap process.   It sets the list of
configuration parameters that will need to be set and "protected" during bootstrap.

If any keys will be set during bootstrap / initial creation of LocalSite.cfg, they
should be added here so that they are preserved when the %Foswiki::cfg hash is
wiped and re-initialized from the Foswiki spec.

=cut

sub setBootstrap {

    # Bootstrap works out the correct values of these keys
    my @BOOTSTRAP =
      qw( {DataDir} {DefaultUrlHost} {PubUrlPath} {ToolsDir} {WorkingDir}
      {PubDir} {TemplateDir} {ScriptDir} {ScriptUrlPath} {ScriptUrlPaths}{view} {ScriptSuffix} {LocalesDir} );

    $Foswiki::cfg{isBOOTSTRAPPING} = 1;
    push( @{ $Foswiki::cfg{BOOTSTRAP} }, @BOOTSTRAP );
}

=begin TML

---++ StaticMethod bootstrapConfig()

This routine is called from Foswiki.pm BEGIN block to discover the mandatory
settings for operation when a LocalSite.cfg could not be found.

=cut

sub bootstrapConfig {

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
    $Foswiki::cfg{ScriptSuffix} = ''
      if ( $Foswiki::cfg{ScriptSuffix} eq '.fcgi' );
    print STDERR
      "AUTOCONFIG: Found SCRIPT SUFFIX $Foswiki::cfg{ScriptSuffix} \n"
      if ( TRAUTO && $Foswiki::cfg{ScriptSuffix} );

    if ( defined $Foswiki::cfg{Engine}
        && $Foswiki::cfg{Engine} ne 'Foswiki::Engine::CLI' )
    {
        _bootstrapWebSettings($script);
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

    # Bootstrap the store related settings.
    _bootstrapStoreSettings();

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
# Don't load LocalSite.cfg if it exists (should normally not exist when bootstrapping)
    Foswiki::Configure::Load::readConfig( 0, 0, 1, 1 );

    _workOutOS();

    $Foswiki::cfg{isVALID} = 1;
    Foswiki::Configure::Load::setBootstrap();

    # Note: message is not I18N'd because there is no point; there
    # is no localisation in a default cfg derived from Foswiki.spec
    my $vp = $Foswiki::cfg{ScriptUrlPaths}{view} || '';
    my $system_message = <<BOOTS;
 *WARNING !LocalSite.cfg could not be found, or failed to load.* %BR%This
Foswiki is running using a bootstrap configuration worked
out by detecting the layout of the installation. Any requests made to this
Foswiki will be treated as requests made by an administrator with full rights
to make changes! You should either:
   * correct any permissions problems with an existing !LocalSite.cfg (see the webserver error logs for details), or
   * visit [[%SCRIPTURL{configure}%?VIEWPATH=$vp][configure]] as soon as possible to generate a new one.
BOOTS

    if ($warn) {
        chomp $system_message;
        $system_message .= $warn . "\n";
    }
    return ( $system_message || '' );

}

=begin TML

---++ StaticMethod _bootstrapStoreSettings()

Called by bootstrapConfig.  This handles the store specific settings.   This in turn
tests each Store Contib to determine if it's capable of bootstrapping.

=cut

sub _bootstrapStoreSettings {

    # Ask each installed store to bootstrap itself.

    my @stores = Foswiki::Configure::FileUtil::findPackages(
        'Foswiki::Contrib::*StoreContrib');

    foreach my $store (@stores) {
        eval("require $store");
        print STDERR $@ if ($@);
        unless ($@) {
            my $ok;
            eval('$ok = $store->can(\'bootstrapStore\')');
            if ($@) {
                print STDERR $@;
            }
            else {
                $store->bootstrapStore() if ($ok);
            }
        }
    }

    # Handle the common store settings managed by Core.  Important ones
    # guessed/checked here include:
    #  - $Foswiki::cfg{Store}{SearchAlgorithm}

    # Set PurePerl search on Windows, or FastCGI systems.
    if ( ( $Foswiki::cfg{Engine} && $Foswiki::cfg{Engine} =~ m/FastCGI/ )
        || $^O eq 'MSWin32' )
    {
        $Foswiki::cfg{Store}{SearchAlgorithm} =
          'Foswiki::Store::SearchAlgorithms::PurePerl';
        print STDERR
"AUTOCONFIG: Detected FastCGI or MS Windows. {Store}{SearchAlgorithm} set to PurePerl\n";
    }
    else {
        ( $ENV{PATH} ) = $ENV{PATH} =~ m/^(.*)$/
          if defined $ENV{PATH};    # Untaint the path
        `grep -V 2>&1`;
        if ($!) {
            print STDERR
"AUTOCONFIG: Unable to find a valid 'grep' on the path. Forcing PurePerl search\n";
            $Foswiki::cfg{Store}{SearchAlgorithm} =
              'Foswiki::Store::SearchAlgorithms::PurePerl';
        }
        else {
            $Foswiki::cfg{Store}{SearchAlgorithm} =
              'Foswiki::Store::SearchAlgorithms::Forking';
            print STDERR
              "AUTOCONFIG: {Store}{SearchAlgorithm} set to Forking\n";
        }
    }
}

=begin TML

---++ StaticMethod _bootstrapWebSettings($script)

Called by bootstrapConfig.  This handles the web environment specific settings only:

   * ={DefaultUrlHost}=
   * ={ScriptUrlPath}=
   * ={ScriptUrlPaths}{view}=
   * ={PubUrlPath}=

=cut

sub _bootstrapWebSettings {
    my $script = shift;

    my $protocol = $ENV{HTTPS} ? 'https' : 'http';

    # Figure out the DefaultUrlHost
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
    elsif ( $ENV{SCRIPT_URI} ) {
        ( $Foswiki::cfg{DefaultUrlHost} ) =
          $ENV{SCRIPT_URI} =~ m#^(https?://[^/]+)/#;
        print STDERR
"AUTOCONFIG: Set DefaultUrlHost $Foswiki::cfg{DefaultUrlHost} from SCRIPT_URI $ENV{SCRIPT_URI} \n"
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
    my $path_info = $ENV{'PATH_INFO'}
      || '';    #SMELL Sometimes PATH_INFO appears to be undefined.
    print STDERR "AUTOCONFIG: REQUEST_URI is $ENV{REQUEST_URI} \n" if (TRAUTO);
    print STDERR "AUTOCONFIG: SCRIPT_URI  is "
      . ( $ENV{SCRIPT_URI} || '(undef)' ) . " \n"
      if (TRAUTO);
    print STDERR "AUTOCONFIG: PATH_INFO   is $path_info \n" if (TRAUTO);
    print STDERR "AUTOCONFIG: ENGINE      is $Foswiki::cfg{Engine}\n"
      if (TRAUTO);

# This code tries to break the url up into <prefix><script><path> ... The script may or may not
# be present.  Short URLs will omit the script from view operations, and *may* omit the
# <prefix> for all operations.   Examples of URLs and shortening.
#
#  Full:    /foswiki/bin/view/Main/WebHome   /foswiki/bin/edit/Main/WebHome
#  Full:    /bin/view/Main/WebHome           /bin/edit/Main/WebHome            omitting prefix
#  Short:   /foswiki/Main/WebHome            /foswiki/bin/edit/Main/WebHome    omitting bin/view
#  Short:   /Main/WebHome                    /bin/edit/Main/WebHome            omitting prefix and bin/view
#  Shorter: /Main/WebHome                    /edit/Main/WebHome                omitting prefix and bin in all cases.
#
# Note that some of this can't be done as part of the view script.  The only way to know if "bin" is omitted in
# all cases is when a script other than view runs,   like jsonrpc.

    my $pfx;

    if ( $Foswiki::cfg{Engine} =~ m/FastCGI/ ) {

#PATH_INFO includes script  /view/System/WebHome,  REQUEST_URI is /System/WebHome.
        ($script) = $ENV{PATH_INFO} =~ m#^/([^/]+)/#;
        $script ||= '';
        print STDERR
"AUTOCONFIG: FCGI Parsed script $script from PATH_INFO $ENV{PATH_INFO} \n"
          if (TRAUTO);
        $pfx = $ENV{SCRIPT_NAME};
        print STDERR
          "AUTOCONFIG: FCGI set Prefix $pfx from \$ENV{SCRIPT_NAME}\n"
          if (TRAUTO);
    }
    else {
        my $suffix =
          ( length( $ENV{SCRIPT_URL} ) < length($path_info) )
          ? $ENV{SCRIPT_URL}
          : $path_info;

        # Try to Determine the prefix of the script part of the URI.
        if ( $ENV{SCRIPT_URI} && $ENV{SCRIPT_URL} ) {
            if ( index( $ENV{SCRIPT_URI}, $Foswiki::cfg{DefaultUrlHost} ) eq 0 )
            {
                $pfx =
                  substr( $ENV{SCRIPT_URI},
                    length( $Foswiki::cfg{DefaultUrlHost} ) );
                $pfx =~ s#$suffix$##;
                print STDERR
"AUTOCONFIG: Calculated prefix $pfx from SCRIPT_URI and SCRIPT_URL\n"
                  if (TRAUTO);
            }
        }
    }

    unless ( defined $pfx ) {
        if ( my $idx = index( $ENV{REQUEST_URI}, $path_info ) ) {
            $pfx = substr( $ENV{REQUEST_URI}, 0, $idx + 1 );
        }
        $pfx = '' unless ( defined $pfx );
        print STDERR "AUTOCONFIG: URI Prefix is $pfx\n" if (TRAUTO);
    }

    # Work out the URL path for Short and standard URLs
    if ( $ENV{REQUEST_URI} =~ m{^(.*?)/$script(\b|$)} ) {
        print STDERR
"AUTOCONFIG: SCRIPT $script fully contained in REQUEST_URI $ENV{REQUEST_URI}, Not short URLs\n"
          if (TRAUTO);

        # Conventional URLs   with path and script
        $Foswiki::cfg{ScriptUrlPath} = $1;
        $Foswiki::cfg{ScriptUrlPaths}{view} =
          $1 . '/view' . $Foswiki::cfg{ScriptSuffix};

        # This might not work, depending on the websrver config,
        # but it's the best we can do
        $Foswiki::cfg{PubUrlPath} = "$1/../pub";
    }
    else {
        print STDERR "AUTOCONFIG: Building Short URL paths using prefix $pfx \n"
          if (TRAUTO);
        $Foswiki::cfg{ScriptUrlPath}        = $pfx . '/bin';
        $Foswiki::cfg{ScriptUrlPaths}{view} = $pfx;
        $Foswiki::cfg{PubUrlPath}           = $pfx . '/pub';
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
