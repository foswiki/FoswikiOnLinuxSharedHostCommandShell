
INSTALLER_SCRIPT_REV = 1

FOSWIKI_RELEASE = 1.0.9

default : foswiki-install-shared-hosting.pl

RELEASE_FILES = Foswiki-$(FOSWIKI_RELEASE)-SharedHosting-$(INSTALLER_SCRIPT_REV).tgz Foswiki-$(FOSWIKI_RELEASE)-SharedHosting-$(INSTALLER_SCRIPT_REV).tgz.md5
release : $(RELEASE_FILES)

ALL : release

Foswiki-$(FOSWIKI_RELEASE)-SharedHosting-$(INSTALLER_SCRIPT_REV).tgz : foswiki-install-shared-hosting.pl
	tar czvf Foswiki-$(FOSWIKI_RELEASE)-SharedHosting-$(INSTALLER_SCRIPT_REV).tgz foswiki-install-shared-hosting.pl

CPAN_LIBS = lib/CPAN/lib/Convert/UU.pm lib/CPAN/lib/Apache/Htpasswd.pm

# NOTE: *always* list a Foswiki distribution as the first data file in the list of uuencoded attachments.  the installer installs the main distribution by its slot position (0)
foswiki-install-shared-hosting.pl : foswiki-install-shared-hosting-preamble.pl $(CPAN_LIBS) Foswiki-$(FOSWIKI_RELEASE).tgz.uuencode FastCGIEngineContrib.tgz.uuencode
	cat foswiki-install-shared-hosting-preamble.pl $(CPAN_LIBS) >foswiki-install-shared-hosting.pl
	echo __END__ >>foswiki-install-shared-hosting.pl
	cat Foswiki-$(FOSWIKI_RELEASE).tgz.uuencode FastCGIEngineContrib.tgz.uuencode >>foswiki-install-shared-hosting.pl
	chmod +x foswiki-install-shared-hosting.pl

Foswiki-$(FOSWIKI_RELEASE)-SharedHosting-$(INSTALLER_SCRIPT_REV).tgz.md5 : Foswiki-$(FOSWIKI_RELEASE)-SharedHosting-$(INSTALLER_SCRIPT_REV).tgz
	md5sum Foswiki-$(FOSWIKI_RELEASE)-SharedHosting-$(INSTALLER_SCRIPT_REV).tgz >Foswiki-$(FOSWIKI_RELEASE)-SharedHosting-$(INSTALLER_SCRIPT_REV).tgz.md5

Foswiki-$(FOSWIKI_RELEASE).tgz.uuencode : Foswiki-$(FOSWIKI_RELEASE).tgz
	perl -Ilib/CPAN/lib/ puuencode Foswiki-$(FOSWIKI_RELEASE).tgz >Foswiki-$(FOSWIKI_RELEASE).tgz.uuencode

FastCGIEngineContrib.tgz.uuencode : FastCGIEngineContrib.tgz
	perl -Ilib/CPAN/lib/ puuencode FastCGIEngineContrib.tgz >FastCGIEngineContrib.tgz.uuencode

Foswiki-$(FOSWIKI_RELEASE).tgz :
	wget 'http://sourceforge.net/projects/foswiki/files/foswiki/Foswiki-$(FOSWIKI_RELEASE).tgz'

FastCGIEngineContrib.tgz :
	wget 'http://foswiki.org/pub/Extensions/FastCGIEngineContrib/FastCGIEngineContrib.tgz'

#

clean :
	-rm *~ $(RELEASE_FILES) foswiki-install-shared-hosting.pl Foswiki-$(FOSWIKI_RELEASE).tgz.uuencode FastCGIEngineContrib.tgz.uuencode 2>/dev/null

realclean : clean
	-rm Foswiki-$(FOSWIKI_RELEASE).tgz FastCGIEngineContrib.tgz 2>/dev/null
