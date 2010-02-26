
INSTALLER_SCRIPT_REV = 1

default : foswiki-install-shared-hosting.pl

release : Foswiki-1.0.9-SharedHosting-$(INSTALLER_SCRIPT_REV).tgz Foswiki-1.0.9-SharedHosting-$(INSTALLER_SCRIPT_REV).tgz.md5

ALL : release

Foswiki-1.0.9-SharedHosting-$(INSTALLER_SCRIPT_REV).tgz : foswiki-install-shared-hosting.pl
	tar czvf Foswiki-1.0.9-SharedHosting-$(INSTALLER_SCRIPT_REV).tgz foswiki-install-shared-hosting.pl

CPAN_LIBS = lib/CPAN/lib/Convert/UU.pm lib/CPAN/lib/Apache/Htpasswd.pm

# NOTE: *always* list a Foswiki distribution as the first data file in the list of uuencoded attachments.  the installer installs the main distribution by its slot position (0)
foswiki-install-shared-hosting.pl : foswiki-install-shared-hosting-preamble.pl $(CPAN_LIBS) Foswiki-1.0.9.tgz.uuencode FastCGIEngineContrib.tgz.uuencode
	cat foswiki-install-shared-hosting-preamble.pl $(CPAN_LIBS) >foswiki-install-shared-hosting.pl
	echo __END__ >>foswiki-install-shared-hosting.pl
	cat Foswiki-1.0.9.tgz.uuencode FastCGIEngineContrib.tgz.uuencode >>foswiki-install-shared-hosting.pl
	chmod +x foswiki-install-shared-hosting.pl

Foswiki-1.0.9-SharedHosting-$(INSTALLER_SCRIPT_REV).tgz.md5 : Foswiki-1.0.9-SharedHosting-$(INSTALLER_SCRIPT_REV).tgz
	md5sum Foswiki-1.0.9-SharedHosting-$(INSTALLER_SCRIPT_REV).tgz >Foswiki-1.0.9-SharedHosting-$(INSTALLER_SCRIPT_REV).tgz.md5

Foswiki-1.0.9.tgz.uuencode : Foswiki-1.0.9.tgz
	perl -Ilib/CPAN/lib/ puuencode Foswiki-1.0.9.tgz >Foswiki-1.0.9.tgz.uuencode

FastCGIEngineContrib.tgz.uuencode : FastCGIEngineContrib.tgz
	perl -Ilib/CPAN/lib/ puuencode FastCGIEngineContrib.tgz >FastCGIEngineContrib.tgz.uuencode

Foswiki-1.0.9.tgz :
	wget 'http://sourceforge.net/projects/foswiki/files/foswiki/Foswiki-1.0.9.tgz'

FastCGIEngineContrib.tgz :
	wget 'http://foswiki.org/pub/Extensions/FastCGIEngineContrib/FastCGIEngineContrib.tgz'

#

clean :
	-rm *~ Foswiki-1.0.9-SharedHosting.tgz Foswiki-1.0.9-SharedHosting.tgz.md5 foswiki-install-shared-hosting.pl Foswiki-1.0.9.tgz.uuencode FastCGIEngineContrib.tgz.uuencode 2>/dev/null

realclean : clean
	-rm Foswiki-1.0.9.tgz FastCGIEngineContrib.tgz 2>/dev/null
