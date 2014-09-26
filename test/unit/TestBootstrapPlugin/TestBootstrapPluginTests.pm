# See the bottom of the file for description, copyright and license information
package TestBootstrapPluginTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use Error (':try');
use Data::Dumper;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

}

sub loadExtraConfig {
    my $this = shift;
    $this->SUPER::loadExtraConfig();
    $Foswiki::cfg{Plugins}{TestBootstrapPlugin}{Enabled} = 1;
    $Foswiki::cfg{Plugins}{TestBootstrapPlugin}{Module} =
      'Foswiki::Plugins::TestBootstrapPlugin';
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub fixture_groups {

    return (
        [ 'Suffix', 'Nosuffix', ],
        [ 'FullURLs', 'ShortURLs', 'MinimumURLs' ],
        [ 'HTTP',     'HTTPS', ],
        [ 'Apache',   'Lighttpd', ],
    );
}

sub ShortURLs {
    my $this = shift;
    $this->{url}      = "short";
    $this->{host}     = "mysite.com";
    $this->{script}   = "/foswiki";
    $this->{viewURL}  = "/foswiki/Main/WebHome";
    $this->{pathinfo} = "/Main/WebHome";
    $this->{pubURL}   = "/foswiki/pub/System/Somefile.txt";

    $this->{PubUrlPath}        = '/foswiki/pub';
    $this->{ScriptUrlPath}     = '/foswiki/bin';
    $this->{ViewScriptUrlPath} = '/foswiki';

    return;
}

sub MinimumURLs {
    my $this = shift;
    $this->{url}        = "minimum";
    $this->{host}       = "mysite.com";
    $this->{viewURL}    = "/Main/WebHome";
    $this->{script}     = "";
    $this->{pathinfo}   = "/Main/WebHome";
    $this->{pubURL}     = "/pub/System/Somefile.txt";
    $this->{PubUrlPath} = '/pub';

    $this->{ScriptUrlPath}     = '/bin';
    $this->{ViewScriptUrlPath} = '';

    return;
}

sub HTTP {
    my $this = shift;
    $this->{protocol} = "http://";

    return;
}

sub HTTPS {
    my $this = shift;
    $this->{protocol} = "https://";

    return;
}

#    # Apache /bin/view    Full URLs
#$ENV{HTTP_HOST} = foswiki.fenachrone.com
#$ENV{HTTP_USER_AGENT} = Mozilla/5.0 (X11; Linux i686; rv:24.0) Gecko/20100101 Firefox/24.0
#$ENV{PATH} = /usr/local/bin:/usr/bin:/bin
#$ENV{PATH_INFO} = /System/TestBootstrapPlugin
#$ENV{PATH_TRANSLATED} = /var/www/foswiki/distro/core/System/TestBootstrapPlugin
#$ENV{QUERY_STRING} = validation_key=97ea6202eda01850bf86544236b10c75
#$ENV{REMOTE_ADDR} = 127.0.0.1
#$ENV{REMOTE_PORT} = 47007
#$ENV{REQUEST_METHOD} = GET
#$ENV{REQUEST_URI} = /bin/view/System/TestBootstrapPlugin?validation_key=97ea6202eda01850bf86544236b10c75
#$ENV{SCRIPT_FILENAME} = /var/www/foswiki/distro/core/bin/view
#$ENV{SCRIPT_NAME} = /bin/view
#$ENV{SCRIPT_URI} = http://foswiki.fenachrone.com/bin/view/System/TestBootstrapPlugin
#$ENV{SCRIPT_URL} = /bin/view/System/TestBootstrapPlugin
#$ENV{SERVER_ADDR} = 127.0.0.1
#$ENV{SERVER_ADMIN} = webmaster@foswiki.fenachrone.com
#$ENV{SERVER_NAME} = foswiki.fenachrone.com
#$ENV{SERVER_PORT} = 80

sub Suffix {
    my $this = shift;

    $this->{suffix} = '.pl';

    return;
}

sub Nosuffix {
    my $this = shift;

    $this->{suffix} = '';

    return;
}

sub FullURLs {
    my $this = shift;

    $this->{url}      = "full";
    $this->{host}     = "mysite.com";
    $this->{script}   = "/foswiki/bin/view" . $this->{suffix};
    $this->{viewURL}  = "/foswiki/bin/view$this->{suffix}/Main/WebHome";
    $this->{pathinfo} = "/Main/WebHome";
    $this->{pubURL}   = "/foswiki/pub/System/Somefile.txt";

    $this->{PubUrlPath}        = '/foswiki/bin/../pub';
    $this->{ScriptUrlPath}     = '/foswiki/bin';
    $this->{ViewScriptUrlPath} = '/foswiki/bin/view';

    return;
}

sub Apache {
    my $this = shift;

    $this->{ENV} = {
        HTTP_HOST   => $this->{host},
        PATH_INFO   => $this->{viewURL},
        REQUEST_URI => $this->{viewURL},
        SCRIPT_URI  => $this->{protocol} . $this->{host} . $this->{viewURL},
        SCRIPT_URL  => $this->{viewURL},
        SCRIPT_NAME => $this->{script},
        PATH_INFO   => $this->{pathinfo},
    };
    return;
}

sub Lighttpd {
    my $this = shift;

    $this->{ENV} = {
        HTTP_HOST   => $this->{host},
        PATH_INFO   => $this->{viewURL},
        REQUEST_URI => $this->{viewURL},
        SCRIPT_URI  => $this->{protocol} . $this->{host} . $this->{viewURL},
        SCRIPT_URL  => $this->{viewURL},
        SCRIPT_NAME => '/bin/view',  # Script name is always present in Lighttpd
        PATH_INFO => $this->{pathinfo},
    };

    return;
}

sub verify_Test_Bootstrap {
    my $this = shift;
    my $msg;
    my $boot_cfg;
    my $resp;

    {
        local %ENV;
        %ENV = %{ $this->{ENV} };

        local *STDERR;
        my $log;
        open STDERR, '>', \$log;

        ( $boot_cfg, $resp ) = $this->_runBootstrap(0);
        close STDERR;
        $msg .= $resp . "\n\n";
        $msg .= $log;
    }

    #print STDERR "BOOTSTRAP RETURNS:\n $msg\n";
    #print STDERR Data::Dumper::Dumper( \$boot_cfg );

    $this->assert_str_equals( $this->{PubUrlPath}, $boot_cfg->{PubUrlPath} );
    $this->assert_str_equals( $this->{ScriptUrlPath},
        $boot_cfg->{ScriptUrlPath} );
    my $suffix = ( $this->{url} eq 'full' ) ? $this->{suffix} : '';
    $this->assert_str_equals(
        $this->{ViewScriptUrlPath} . $suffix,
        $boot_cfg->{ScriptUrlPaths}{view}
    );

    return;
}

sub verify_Core_Bootstrap {
    my $this = shift;
    my $msg;
    my $boot_cfg;
    my $resp;

    {
        local %ENV;
        %ENV = %{ $this->{ENV} };

        local *STDERR;
        my $log;
        open STDERR, '>', \$log;

        ( $boot_cfg, $resp ) = $this->_runBootstrap(1);
        close STDERR;
        $msg .= $resp . "\n\n";
        $msg .= $log;
    }

    #print STDERR "BOOTSTRAP RETURNS:\n $msg\n";

    #print STDERR Data::Dumper::Dumper( \$boot_cfg );

    $this->assert_str_equals( $this->{PubUrlPath}, $boot_cfg->{PubUrlPath} );
    $this->assert_str_equals( $this->{ScriptUrlPath},
        $boot_cfg->{ScriptUrlPath} );
    my $suffix = ( $this->{url} eq 'full' ) ? $this->{suffix} : '';
    $this->assert_str_equals(
        $this->{ViewScriptUrlPath} . $suffix,
        $boot_cfg->{ScriptUrlPaths}{view}
    );

    return;
}

#   # lighttpd bin/configure
#HTTP_HOST  lf117.fenachrone.com
#REQUEST_URI    /bin/configure
#SCRIPT_FILENAME    /var/www/servers/Foswiki-1.1.7/bin/configure
#SCRIPT_NAME    /bin/configure
#SERVER_NAME    lf117.fenachrone.com
#SERVER_PORT    80

#   # Apache bin/configure
#HTTP_HOST  f119.fenachrone.com
#REQUEST_URI    /bin/configure
#SCRIPT_FILENAME    /var/www/data/Foswiki-1.1.9/bin/configure
#SCRIPT_NAME    /bin/configure
#SCRIPT_URI http://f119.fenachrone.com/bin/configure
#SCRIPT_URL /bin/configure
#SERVER_ADDR    127.0.0.1
#SERVER_ADMIN   webmaster@fenachrone.com
#SERVER_NAME    f119.fenachrone.com
#SERVER_PORT    80

#    # Apache /bin/view    Full URLs
#$ENV{HTTP_HOST} = foswiki.fenachrone.com
#$ENV{HTTP_USER_AGENT} = Mozilla/5.0 (X11; Linux i686; rv:24.0) Gecko/20100101 Firefox/24.0
#$ENV{PATH} = /usr/local/bin:/usr/bin:/bin
#$ENV{PATH_INFO} = /System/TestBootstrapPlugin
#$ENV{PATH_TRANSLATED} = /var/www/foswiki/distro/core/System/TestBootstrapPlugin
#$ENV{QUERY_STRING} = validation_key=97ea6202eda01850bf86544236b10c75
#$ENV{REMOTE_ADDR} = 127.0.0.1
#$ENV{REMOTE_PORT} = 47007
#$ENV{REQUEST_METHOD} = GET
#$ENV{REQUEST_URI} = /bin/view/System/TestBootstrapPlugin?validation_key=97ea6202eda01850bf86544236b10c75
#$ENV{SCRIPT_FILENAME} = /var/www/foswiki/distro/core/bin/view
#$ENV{SCRIPT_NAME} = /bin/view
#$ENV{SCRIPT_URI} = http://foswiki.fenachrone.com/bin/view/System/TestBootstrapPlugin
#$ENV{SCRIPT_URL} = /bin/view/System/TestBootstrapPlugin
#$ENV{SERVER_ADDR} = 127.0.0.1
#$ENV{SERVER_ADMIN} = webmaster@foswiki.fenachrone.com
#$ENV{SERVER_NAME} = foswiki.fenachrone.com
#$ENV{SERVER_PORT} = 80

#    # Apache   foswiki/System/Test...    Short URLs with prefix
# $ENV{HTTP_HOST} = foswiki.fenachrone.com
# $ENV{HTTP_USER_AGENT} = Mozilla/5.0 (X11; Linux i686; rv:24.0) Gecko/20100101 Firefox/24.0
# $ENV{PATH} = /usr/local/bin:/usr/bin:/bin
# $ENV{PATH_INFO} = /System/TestBootstrapPlugin
# $ENV{PATH_TRANSLATED} = /var/www/foswiki/distro/core/System/TestBootstrapPlugin
# $ENV{QUERY_STRING} = validation_key=97ea6202eda01850bf86544236b10c75
# $ENV{REMOTE_ADDR} = 127.0.0.1
# $ENV{REMOTE_PORT} = 47015
# $ENV{REQUEST_METHOD} = GET
# $ENV{REQUEST_URI} = /foswiki/System/TestBootstrapPlugin?validation_key=97ea6202eda01850bf86544236b10c75
# $ENV{SCRIPT_FILENAME} = /var/www/foswiki/distro/core/bin/view
# $ENV{SCRIPT_NAME} = /foswiki
# $ENV{SCRIPT_URI} = http://foswiki.fenachrone.com/foswiki/System/TestBootstrapPlugin
# $ENV{SCRIPT_URL} = /foswiki/System/TestBootstrapPlugin
# $ENV{SERVER_ADDR} = 127.0.0.1
# $ENV{SERVER_ADMIN} = webmaster@foswiki.fenachrone.com
# $ENV{SERVER_NAME} = foswiki.fenachrone.com
# $ENV{SERVER_PORT} = 80

#   # lighttpd bin/view   Short URLs
#HTTP_HOST = lf117.fenachrone.com
#PATH_INFO = /System/TestBootstrapPlugin
#REQUEST_URI = /System/TestBootstrapPlugin
#SCRIPT_FILENAME = /var/www/servers/Foswiki-1.1.7/bin/view
#SCRIPT_NAME = /bin/view
#SERVER_ADDR = 0.0.0.0
#SERVER_NAME = lf117.fenachrone.com
#SERVER_PORT = 80
#SERVER_PROTOCOL = HTTP/1.1

sub _again { return; }

sub _runBootstrap {
    my $this     = shift;
    my $coreTest = shift;

    local %Foswiki::cfg = ( Engine => $Foswiki::cfg{Engine} );
    my $msg;

    no warnings 'redefine';
    require FindBin;
    *FindBin::again = \&_again;
    use warnings 'redefine';
    $FindBin::Bin    = '/var/www/foswiki/distro/core/bin';
    $FindBin::Script = 'view' . $this->{suffix};

    if ( $coreTest && Foswiki::Configure::Load->can('bootstrapConfig') ) {
        $msg = Foswiki::Configure::Load::bootstrapConfig(1);
    }
    else {
        $msg = Foswiki::Plugins::TestBootstrapPlugin::_bootstrapConfig(1);
    }

    $msg .= "\n\n";
    foreach my $ek ( sort keys %ENV ) {
        $msg .= "\$ENV{$ek} = $ENV{$ek} \n";
    }

    return ( \%Foswiki::cfg, $msg );
}

1;
__END__

Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014 George Clark and Foswiki Contributors.
All Rights Reserved. Foswiki Contributors
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

For licensing info read LICENSE file in the Foswiki root.

Author: George Clark
