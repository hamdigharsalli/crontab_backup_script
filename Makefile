all::
	@echo "There is nothing to build in this directory."

crontab_backup_script = crontab_backup_script.sh

script:
	vi $(crontab_backup_script)

vi:
	make readme

install:
	@echo "scp $(crontab_backup_script) user@dest:"

include common.mk

