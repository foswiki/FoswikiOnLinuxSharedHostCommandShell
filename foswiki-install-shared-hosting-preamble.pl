#! /usr/bin/perl -w
# Copyright (c) 2010, Will Norris.  Licensed under the GPLv2.
# Version 1.0.0 - 9 Feb 2010
use strict;
use warnings;
use Data::Dumper qw( Dumper );

################################################################################
use Getopt::Long;
GetOptions( my $opts = {},
	    'verbose',
	    'debug',
	    'admin=s',
	    'hostname=s',
	    'puburl=s',
	    'email=s',	# email@example.com
	    );
#print "VERBOSE=[$opts->{verbose}], DEBUG=[$opts->{debug}]\n";
################################################################################

chomp( my $pwd = `pwd` );
# dreamhost-specific: remove symlink in /home/.symlink-to-actual-drive/account/...
# otherwise, this can cause problems if they move your account to different attached storage
# NOTE: this is benign on systems that don't use this format of .filename symlinks
$pwd =~ s{^(/home)/\..+?(/.+)}{$1$2};
DEBUG( "pwd=[$pwd]" );

my $foswiki_root = $pwd;
DEBUG( "foswiki_root=[$foswiki_root]" );

################################################################################
# welcome banner
unless ( $opts->{hostname} and $opts->{email} ) {
    print <<__WELCOME__;
This script will install Foswiki v1.0.9 to "$pwd"
The following information will be needed:
1. domain name
   * (optional) a separate subdomain for pub
2. wiki webmaster email address
__WELCOME__
}

################################################################################
# domain name
my ( $DefaultUrlHost, $foswiki_url );
if ( $opts->{hostname} ) {
    $DefaultUrlHost = $opts->{hostname};
    ( undef, $foswiki_url ) = $pwd =~ m{^/home/[^/]+/([^/]+)(.*)};
} else {
    print "\n1. Domain name\n";
    ( $DefaultUrlHost, $foswiki_url ) = $pwd =~ m{^/home/[^/]+/([^/]+)(.*)};
    DEBUG( "DefaultUrlHost=[$DefaultUrlHost], foswiki_url=[$foswiki_url]" );
    # prepend "www." if we're not in a subdomain (eg, example.com instead of wiki.example.com or www.example.com)
    if ( $#{ [split /\./, $DefaultUrlHost]} == 1 ) {
	print "Domain name: \"www.\" automatically prepended.  Although you aren't required to locate the wiki in a subdomain, doing so will allow you to later\ncreate another subdomain to serve the static content from pub, improving page load performance.\n(see http://developer.yahoo.com/performance/rules.html#cookie_free)\n";
	$DefaultUrlHost = "www.$DefaultUrlHost";
    }
    DEBUG( "DefaultUrlHost=[$DefaultUrlHost], foswiki_url=[$foswiki_url]" );
    print "Domain name guessed; press ENTER to accept or enter a new value to override ($DefaultUrlHost): ";
    chomp( my $user_hostname = <STDIN> );
    $DefaultUrlHost = $user_hostname if length $user_hostname;
}

my $PubUrlPath = "$foswiki_url/pub";	# /foswiki/pub, pub.example.com
if ( $opts->{puburl} ) {
    $PubUrlPath = $opts->{puburl};
} elsif ( $opts->{hostname} ) {
    ;# default PubUrlPath is a fine default when hostname specified, but puburl not
} else {
    # optional pub content subdomain
    if ( $#{ [split /\./, $DefaultUrlHost]} >= 2 ) {	# subdomain.example.com == 2
	print "Do you want to specify a separate domain for pub? (y/n): ";
	chomp( my $pub_subdomain_q = <STDIN> );
	if ( $pub_subdomain_q =~ /^y/i ) {
#            $PubUrlPath = my $pub_subdomain_default = join( '.', 'pub', (split( /\./, $DefaultUrlHost ))[1,1e6] );	# strip off first subdomain, replace with "pub"
	    $PubUrlPath = my $pub_subdomain_default = join( '.', 'pub', eval { my @a = split( /\./, $DefaultUrlHost ); shift @a; return @a } );
	    DEBUG( "pub_subdomain_default=[$pub_subdomain_default]" );
	    print "Enter pub subdomain ($pub_subdomain_default): ";
	    chomp( my $pub_subdomain_prompt = <STDIN> );
	    DEBUG( "pub_subdomain_prompt=[$pub_subdomain_prompt]" );
	    $PubUrlPath = $pub_subdomain_prompt if length $pub_subdomain_prompt;
	    DEBUG( "PubUrlPath=[$PubUrlPath]" );
	    $PubUrlPath = "http://$PubUrlPath" unless $PubUrlPath =~ m{^https?://};
	    DEBUG( "PubUrlPath=[$PubUrlPath]" );
	}
    }
}
# TOOO: create pub directory now so that people can create the pub subdomain?

my $DataDir = $foswiki_root . '/data';
my $ScriptUrlPath = "$foswiki_url/bin";

################################################################################
# extract and uudecode the embedded files, make available by index and name
my $data = join( '', <main::DATA> );
my @archive = ( $data =~ /(begin 0?\d{3}.*?end)/gs );		# SMELL: regex could be tighter
die "wrong number of archive (" . scalar(@archive) . "), should be 2" if scalar @archive != 2;
my %archive = map { /^begin\s+0?\d{3}\s+(.+?)\n/; ( $1 => $_ ) } @archive;	# make accessible via hash keyed by 'name'

################################################################################
# extract the foswiki distribution
unless ( -e "$foswiki_root/bin/view" ) {
    my ($uudecoded_string,$name,$mode) = Convert::UU::uudecode( $archive[0] );	# use first slot which should contain a Foswiki distribution
    VERBOSE( "Decompressing Foswiki" );
    open( TAR, '|-', tar => '-xz', '--strip'=>'1' );
    print TAR $uudecoded_string;
    close TAR;
    # SMELL: test for error from tar
}

################################################################################
# bin/LocalLib.cfg
unless ( -e "$foswiki_root/bin/LocalLib.cfg" ) {
    VERBOSE( "Creating bin/LocalLib.cfg" );
    system( cp => "$foswiki_root/bin/LocalLib.cfg.txt" => "$foswiki_root/bin/LocalLib.cfg" )
}
system( qq{sed -i -e 's|/absolute/path/to/your/lib|$foswiki_root/lib|' $foswiki_root/bin/LocalLib.cfg} );

my $password = generate_password();
DEBUG( "password=[$password]" );

################################################################################
# .htpasswd
my $Administrators = $opts->{admin} || 'admin';
my $htpasswd_file = "$foswiki_root/data/.htpasswd";
# SMELL - could be better, like checking for $Administrators in the password file
unless ( -e $htpasswd_file ) {
    print "Creating data/.htpasswd and setting the password to access configure\n";

    print "A secure password for configure (access and save) has been generated for you: $password\n";
    system( htpasswd => '-b', '-c' => $htpasswd_file, $Administrators, $password );
    # TODO: use Apache::Htpasswd
    # my $htpasswd = new Apache::Htpasswd( $htpasswd_file );
    # $htpasswd->htpasswd( $Administrators, $password, { overwrite => 1 } );
}

################################################################################
## .htaccess files
################################################################################
# foswiki root .htaccess
unless ( -e "$foswiki_root/.htaccess" ) {
    VERBOSE( "Creating foswiki root .htaccess (with redirect from the foswiki root directory to the wiki itself)" );
    system( cp => "$foswiki_root/root-htaccess.txt" => "$foswiki_root/.htaccess" );
    system( chmod => 'u+w' => "$foswiki_root/.htaccess" );
    open( FH, '>>', "$foswiki_root/.htaccess" ) or die $!;
    print FH "Redirect $foswiki_url/index.html http://$DefaultUrlHost$foswiki_url/bin/view", "\n";
    close( FH );
    system( chmod => 'u-w' => "$foswiki_root/.htaccess" );
}

################################################################################
# bin/.htaccess
# enables FastCGI (if available) as well as mod_deflate (if available)
# it is questionable whether it is better to enable mod_deflate on an overloaded shared system or not :/
unless ( -e "$foswiki_root/bin/.htaccess" ) {
    VERBOSE( "Creating bin/.htaccess (including FastCGI and mod_deflate support)" );
    system( cp => "$foswiki_root/bin/.htaccess.txt" => "$foswiki_root/bin/.htaccess" );
    system( qq{sed -i -e 's|\{DataDir\}|$DataDir|g' $foswiki_root/bin/.htaccess} );
    system( qq{sed -i -e 's|\{DefaultUrlHost\}|$DefaultUrlHost|g' $foswiki_root/bin/.htaccess} );
    system( qq{sed -i -e 's|\{ScriptUrlPath\}|$ScriptUrlPath|g' $foswiki_root/bin/.htaccess} );
    system( qq{sed -i -e 's|\{Administrators\}|$Administrators|g' $foswiki_root/bin/.htaccess} );

    my ($uudecoded_string,$name,$mode) = Convert::UU::uudecode( $archive{'FastCGIEngineContrib.tgz'} );
    VERBOSE( "Decompressing FastCGIEngineContrib" );
    open( TAR, '|-', tar => '-xz' );
    print TAR $uudecoded_string;
    close TAR;
    # SMELL: test for error from tar

    my $fastcgi = <<'__FASTCGI__';
<ifmodule mod_fastcgi.c>
    SetHandler fastcgi-script
    RewriteEngine on
    RewriteCond %{REQUEST_URI} !/configure
    RewriteCond %{REQUEST_URI} !/foswiki.fcgi
    RewriteRule ^(.*) foswiki.fcgi/$1 [L]
</ifmodule>
__FASTCGI__

    my $compress = <<'__DEFLATE__';
<ifmodule mod_deflate.c>
    SetOutputFilter DEFLATE
    AddOutputFilterByType DEFLATE text/html application/xhtml+xml application/xml text/plain text/xml
</ifmodule>
__DEFLATE__

    open( FH, '>>', "$foswiki_root/bin/.htaccess" ) or die $!;
    print FH $fastcgi;
    print FH $compress;
    close( FH );
}

################################################################################
# pub/.htaccess
unless ( -e "$foswiki_root/pub/.htaccess" ) {
    VERBOSE( "Creating pub/.htaccess (including mod_expire and mod_deflate support)" );
    system( cp => "$foswiki_root/pub-htaccess.txt" => "$foswiki_root/pub/.htaccess" );
    system( qq{sed -i -e 's|/foswiki/bin/viewfile|$foswiki_url/bin/viewfile|' $foswiki_root/pub/.htaccess} );

    my $compress = <<'__MOD_DEFLATE__';
<ifmodule mod_expires.c>
  <filesmatch "\.(jpg|gif|png|css|js|ico)$">
       ExpiresActive on
       ExpiresDefault "access plus 11 days"
   </filesmatch>
</ifmodule>
<ifmodule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/css application/x-javascript application/javascript 
</ifmodule>
__MOD_DEFLATE__

    system( chmod => 'u+w' => "$foswiki_root/pub/.htaccess" );
    open( FH, '>>', "$foswiki_root/pub/.htaccess" ) or die $!;
    print FH $compress;
    close( FH );
    system( chmod => 'u-w' => "$foswiki_root/pub/.htaccess" );
}

################################################################################
# .htaccess in the remaining directories: data, lib, locale, templates, tools, working
foreach my $subdir qw( data lib locale templates tools working ) {
    unless ( -e "$foswiki_root/$subdir/.htaccess" ) {
        VERBOSE( "Creating $subdir/.htaccess to deny access" );
        system( cp => "$foswiki_root/subdir-htaccess.txt" => "$foswiki_root/$subdir/.htaccess" );
    }
}

################################################################################
# lib/LocalSite.cfg
my $WikiWebMasterEmail;	# email@example.com
unless ( -e "$foswiki_root/lib/LocalSite.cfg" ) {
    VERBOSE( "Performing final Foswiki configuration" );

    my $encrypted_password = _encode_password( $password );
    if ( $opts->{email} ) {
        $WikiWebMasterEmail = $opts->{email};
    } else {
        print "\n2. Wiki webmaster email address (required for registration): ";
        chomp( $WikiWebMasterEmail = <STDIN> );
    }

my $libLocalSiteCfg = <<__LIB_LOCALSITE_CFG__;
# Local site settings for Foswiki. This file is managed by the 'configure'
# CGI script, though you can also make (careful!) manual changes with a
# text editor.
\$Foswiki::cfg{DefaultUrlHost} = 'http://$DefaultUrlHost';
\$Foswiki::cfg{PermittedRedirectHostUrls} = '';
\$Foswiki::cfg{ScriptUrlPath} = '$foswiki_url/bin';
\$Foswiki::cfg{PubUrlPath} = '$PubUrlPath';
\$Foswiki::cfg{PubDir} = '$foswiki_root/pub';
\$Foswiki::cfg{TemplateDir} = '$foswiki_root/templates';
\$Foswiki::cfg{DataDir} = '$foswiki_root/data';
\$Foswiki::cfg{LocalesDir} = '$foswiki_root/locale';
\$Foswiki::cfg{WorkingDir} = '$foswiki_root/working';
\$Foswiki::cfg{ScriptSuffix} = '';
\$Foswiki::cfg{WebMasterEmail} = '$WikiWebMasterEmail';
\$Foswiki::cfg{Password} = '$encrypted_password';
1;
__LIB_LOCALSITE_CFG__

    open( FH, '>', "$foswiki_root/lib/LocalSite.cfg" ) or die $!;
    print FH $libLocalSiteCfg;
    close( FH );
}

################################################################################
# COMPLETION!
my $configure = "http://$DefaultUrlHost$foswiki_url/bin/configure";

if ( 0 ) {	# sadly, i haven't gotten this working
	     use WWW::Mechanize;
	     use MIME::Base64;
	     my $mech = WWW::Mechanize->new( agent => $0, cookie_jar => {}, autocheck => 1 );
	     $mech->credentials( $Administrators => $password );
#?	     $mech->add_header( Authorization => 'Basic ' . MIME::Base64::encode( $Administrators . ':' . $password ) );
	     
	     $mech->get( $configure );
	     $mech->submit_form( form_name => 'update' );
	     die unless $mech->success;
	     warn Dumper( $mech->forms );
	     # could set the password via configure the first time (newCfgP and confCfgP), but it's safer to do it manually 
	     # above to prevent leaving the wiki unprotected in case something goes wrong withe this configure process
	     $mech->submit_form( with_fields => { cfgAccess => $password } );
	     die unless $mech->success;
	     print "\nWiki installation and configuration completed.  Your wiki is available at http://$DefaultUrlHost$foswiki_url/bin/view\nEnjoy!\n";
	 } else {
	     print "\nYou *MUST* perform a *SAVE* at $configure to complete the installation of your wiki.\nEnjoy!\n";
#	     system( lynx => $configure );
	 }
exit 0;

################################################################################
################################################################################

# same as standard settings for http://goodpassword.com
sub generate_password {
    my $length = 12;
    my $valid_password_chars = q|23456789abcdefghjkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ|;
    my $password = join( '', ( map { substr( $valid_password_chars, int( rand length $valid_password_chars ), 1 ) } ( 1..$length ) ) );
    return $password;
}

# from lib/Foswiki/Configure/UI.pm sub _encode
sub _encode_password {
    my $pass = shift;
    my @saltchars = ( 'a' .. 'z', 'A' .. 'Z', '0' .. '9', '.', '/' );
    # SMELL: why not simple length instead of $# + 1 ?
    my $salt = $saltchars[ int( rand( $#saltchars + 1 ) ) ] . $saltchars[ int( rand( $#saltchars + 1 ) ) ];
    return crypt( $pass, $salt );
}

################################################################################

sub VERBOSE {
    print @_, "\n" if $opts->{verbose};
}

sub DEBUG {
    print @_, "\n" if $opts->{debug};
}

################################################################################
package ConfigureMech;
use WWW::Mechanize;

use vars qw(@ISA);
@ISA = qw(WWW::Mechanize);

sub new {
    my $self = WWW::Mechanize::new(@_);
    $self;
}

sub get_basic_credentials {
    my ($self, $realm, $uri) = @_;
    return( $Administrators, $password );
}
1;

################################################################################
# TODO: (see also http://foswiki.org/Development/FoswikiOnLinuxSharedHostCommandShell)
#   * support ShortURLs
#   * perform the initial configure save via this script (STUCK)
#   * use Apache::Htpasswd (which also means i don't have to look for htpasswd or htpasswd2)
#   * use WWW::Mechanize::Foswiki to drive configure
#   * provide CPAN installation support
#   * add "Cache-Control: private" and "KeepAlive on" (http://www.die.net/musings/page_load_time/) to pub/.htaccess ?
#   * ability to disable mod_deflate support on pub (better to serve the raw file instead of trying to compress it on an overloaded shared host?)
#   * test and support (better) https
#   * trivial browser frontend for ftp installation
################################################################################
# NOTES:
#   * http://cgipan.cvs.sourceforge.net/cgipan/cgipan/cgipan.cgi?view=markup
#   * http://search.cpan.org/dist/Shipwright/lib/Shipwright.pm
#   * http://search.cpan.org/dist/pip/lib/pip.pm
#   * http://search.cpan.org/dist/PAR/
################################################################################
## EOF - foswiki-install-shared-hosting-preamble.pl
################################################################################
################################################################################


