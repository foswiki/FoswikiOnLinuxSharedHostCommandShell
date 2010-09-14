
INSTALLER_SCRIPT_REV = 1

FOSWIKI_RELEASE = 1.0.9

FOSWIKI_BASE_FILENAME = Foswiki-$(FOSWIKI_RELEASE)
INSTALLER_SCRIPT_FILENAME = $(FOSWIKI_BASE_FILENAME)-SharedHosting-$(INSTALLER_SCRIPT_REV).tgz

default : foswiki-install-shared-hosting.pl

RELEASE_FILES = $(INSTALLER_SCRIPT_FILENAME) $(INSTALLER_SCRIPT_FILENAME).md5
release : $(RELEASE_FILES)

ALL : release

$(INSTALLER_SCRIPT_FILENAME) : foswiki-install-shared-hosting.pl
	tar czvf $(INSTALLER_SCRIPT_FILENAME) foswiki-install-shared-hosting.pl

CPAN_LIBS = lib/CPAN/lib/Convert/UU.pm lib/CPAN/lib/Apache/Htpasswd.pm

# NOTE: *always* list a Foswiki distribution as the first data file in the list of uuencoded attachments.  the installer installs the main distribution by its slot position (0)
foswiki-install-shared-hosting.pl : foswiki-install-shared-hosting-preamble.pl $(CPAN_LIBS) $(FOSWIKI_BASE_FILENAME).tgz.uuencode FastCGIEngineContrib.tgz.uuencode
	cat foswiki-install-shared-hosting-preamble.pl $(CPAN_LIBS) >foswiki-install-shared-hosting.pl
	echo __END__ >>foswiki-install-shared-hosting.pl
	cat $(FOSWIKI_BASE_FILENAME).tgz.uuencode FastCGIEngineContrib.tgz.uuencode >>foswiki-install-shared-hosting.pl
	chmod +x foswiki-install-shared-hosting.pl

$(INSTALLER_SCRIPT_FILENAME).md5 : $(INSTALLER_SCRIPT_FILENAME)
	md5sum $(INSTALLER_SCRIPT_FILENAME) >$(INSTALLER_SCRIPT_FILENAME).md5

$(FOSWIKI_BASE_FILENAME).tgz.uuencode : $(FOSWIKI_BASE_FILENAME).tgz
	perl -Ilib/CPAN/lib/ puuencode $(FOSWIKI_BASE_FILENAME).tgz >$(FOSWIKI_BASE_FILENAME).tgz.uuencode

FastCGIEngineContrib.tgz.uuencode : FastCGIEngineContrib.tgz
	perl -Ilib/CPAN/lib/ puuencode FastCGIEngineContrib.tgz >FastCGIEngineContrib.tgz.uuencode

$(FOSWIKI_BASE_FILENAME).tgz :
	wget 'http://sourceforge.net/projects/foswiki/files/foswiki/$(FOSWIKI_BASE_FILENAME).tgz'

FastCGIEngineContrib.tgz :
	wget 'http://foswiki.org/pub/Extensions/FastCGIEngineContrib/FastCGIEngineContrib.tgz'

#

clean :
	-rm *~ $(RELEASE_FILES) foswiki-install-shared-hosting.pl $(FOSWIKI_BASE_FILENAME).tgz.uuencode FastCGIEngineContrib.tgz.uuencode 2>/dev/null

realclean : clean
	-rm $(FOSWIKI_BASE_FILENAME).tgz FastCGIEngineContrib.tgz 2>/dev/null
