build_counter = build_counter.txt
script_source = crontab_backup_script.sh

version_number_value = $(shell cat ${build_counter})

all::
	sed -i 's/\(script_version=\)[0-9]*/\1$(version_number_value)/g' $(script_source)
	@echo $$(($$(cat $(build_counter)) + 1)) > $(build_counter)
	make commit
	make install

script:
	vi $(script_source)

vi:
	make script

clean::
	unlink consolidated_bibtex_file.bib

install: private-install-crontab_backup_script

include common.mk
include private.mk

