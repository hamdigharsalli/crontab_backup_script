all::
	@echo "There is nothing to build in this directory."

script_source = crontab_backup_script.sh

script:
	vi $(script_source)

vi:
	make script

install: private-install-crontab_backup_script

include common.mk
include private.mk

