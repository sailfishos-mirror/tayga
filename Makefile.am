DEFS = -DTAYGA_CONF_PATH=\"$(tayga_conf_path)\"

sbin_PROGRAMS = tayga

dist_sysconf_DATA = tayga.conf.example

dist_man_MANS = tayga.8 tayga.conf.5

tayga_SOURCES = nat64.c addrmap.c dynamic.c tayga.c conffile.c tayga.h list.h

# See daemon(7)
AM_DISTCHECK_CONFIGURE_FLAGS = \
 --with-systemdsystemunitdir=$$dc_install_base/$(systemdsystemunitdir)
if HAVE_SYSTEMD
systemdsystemunit_DATA = tayga.service tayga@.service
endif
