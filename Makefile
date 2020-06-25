#!/usr/bin/make -f
# Makefile for code-generation #
# ---------------------- #
# Created by newlaurent62
#
PREFIX = /usr/local
TEMPLATES_DIR = share/rayZ-builder/session-templates
PYTHON := /usr/bin/python3
#WIZARD := simple_example
WIZARD := Jamulus
RAY_SESSION_ROOT := "/home/laurent/Ray Sessions"
DEFAULT_FILES := $(patsubst %, %.py, $(wildcard src/wizards/$(WIZARD)))
ALL_FILES := $(patsubst %, %.py, $(wildcard src/wizards/*))
TMPL_ARGS := --debug
# -----------------------------------------------------------------------------------------------------------------------------------------


all: $(ALL_FILES)

build: $(DEFAULT_FILES)

%.py : WIZARD_ID=$(patsubst src/wizards/%,%, $<)
%.py : %
	
	echo "--"
	echo -e "-- WIZARD_ID: \e[1m$(WIZARD_ID)\e[0m from $<"
	echo "--"
	
	mkdir -p build/$(WIZARD_ID)/xml build/$(TEMPLATES_DIR)/$(WIZARD_ID)
	#cp src/package-def/__init__.py build/$(TEMPLATES_DIR)/$(WIZARD_ID)/__init__.py

	cp src/wizards/$(WIZARD_ID)/*.wizard src/wizards/$(WIZARD_ID)/pages/*.page build/$(WIZARD_ID)/xml/
	test -d src/wizards/$(WIZARD_ID)/snippets && cp src/wizards/$(WIZARD_ID)/snippets/*.tmpl_snippet build/$(WIZARD_ID)/xml/ || exit 0
	cheetah3 c -R --nobackup --idir src/wizards/$(WIZARD_ID)/tmpl --odir build/$(TEMPLATES_DIR)/$(WIZARD_ID)/

	mkdir -p build/$(TEMPLATES_DIR)/$(WIZARD_ID)/
	
	xmllint --xinclude --schema src/xsd/wizard.xsd build/$(WIZARD_ID)/xml/$(WIZARD_ID).wizard > build/$(TEMPLATES_DIR)/$(WIZARD_ID)/xi-wizard.xml
	
	saxonb-xslt -s:build/$(TEMPLATES_DIR)/$(WIZARD_ID)/xi-wizard.xml -xsl:"src/xsl/tmpl_wizard.xsl" -o:"build/$(TEMPLATES_DIR)/$(WIZARD_ID)/tmpl_wizard.py"
	saxonb-xslt -s:build/$(TEMPLATES_DIR)/$(WIZARD_ID)/xi-wizard.xml -xsl:"src/xsl/install.xsl" -o:"build/$(TEMPLATES_DIR)/$(WIZARD_ID)/install_dep_wizard.sh"
	saxonb-xslt -s:build/$(TEMPLATES_DIR)/$(WIZARD_ID)/xi-wizard.xml -xsl:"src/xsl/info-template.xsl" -o:"build/$(TEMPLATES_DIR)/$(WIZARD_ID)/info_wizard.xml"
	saxonb-xslt -s:build/$(TEMPLATES_DIR)/$(WIZARD_ID)/xi-wizard.xml -xsl:"src/xsl/patch_xml-gen_tmpl.xsl" -o:"build/$(TEMPLATES_DIR)/$(WIZARD_ID)/patch_xml.tmpl"
	saxonb-xslt -s:build/$(TEMPLATES_DIR)/$(WIZARD_ID)/patch_xml.tmpl -xsl:"src/xsl/nsm-patch.xsl" -o:"build/$(TEMPLATES_DIR)/$(WIZARD_ID)/nsm_patch.tmpl"

	# create session_sh.tmpl from XML declaration in template_snippet[@ref-id='session_sh']
	saxonb-xslt -s:build/$(TEMPLATES_DIR)/$(WIZARD_ID)/xi-wizard.xml -xsl:"src/xsl/session_xml.xsl" -o:"build/$(WIZARD_ID)/xml/session.xml"
	xmllint --xinclude --schema "src/xsd/session.xsd" "build/$(WIZARD_ID)/xml/session.xml" > "build/$(WIZARD_ID)/xml/xi-session.xml"
	saxonb-xslt -s:build/$(WIZARD_ID)/xml/xi-session.xml -xsl:"src/xsl/session_sh-gen_tmpl.xsl" -o:"build/$(TEMPLATES_DIR)/$(WIZARD_ID)/session_sh.tmpl"
	perl -pi -e "s|xxx-LOCALEPATH-xxx|build/$(TEMPLATES_DIR)/$(WIZARD_ID)/locale|g;" "build/$(TEMPLATES_DIR)/$(WIZARD_ID)/session_sh.tmpl"

	saxonb-xslt -s:build/$(TEMPLATES_DIR)/$(WIZARD_ID)/xi-wizard.xml -xsl:"src/xsl/ray_script_load_sh-gen_tmpl.xsl" -o:"build/$(TEMPLATES_DIR)/$(WIZARD_ID)/ray_script_load_sh.tmpl"


	cheetah3 c -R --nobackup --idir "build/$(TEMPLATES_DIR)/$(WIZARD_ID)" --odir "build//$(TEMPLATES_DIR)/$(WIZARD_ID)"
	mkdir -p "build/$(TEMPLATES_DIR)/$(WIZARD_ID)/local/bin" "build/$(TEMPLATES_DIR)/$(WIZARD_ID)/local/share/icons" "build/$(TEMPLATES_DIR)/$(WIZARD_ID)/default"
	cp -r src/gui/rayZ_ui.py "build/$(TEMPLATES_DIR)/$(WIZARD_ID)/"
	test -d src/wizards/$(WIZARD_ID)/default && cp -r src/wizards/$(WIZARD_ID)/default "build/$(TEMPLATES_DIR)/$(WIZARD_ID)/" || exit 0
	test -d src/wizards/$(WIZARD_ID)/local && cp -r src/wizards/$(WIZARD_ID)/local "build/$(TEMPLATES_DIR)/$(WIZARD_ID)/" || exit 0
	test -d src/ray-scripts && cp -r src/ray-scripts "build/$(TEMPLATES_DIR)/$(WIZARD_ID)/" || exit 0
	test -d src/wizards/$(WIZARD_ID)/ray-scripts && cp -r src/wizards/$(WIZARD_ID)/ray-scripts "build/$(TEMPLATES_DIR)/$(WIZARD_ID)/" || exit 0
	test -d src/wizards/$(WIZARD_ID)/rayZ-bin/ && mkdir -p "build/$(TEMPLATES_DIR)/$(WIZARD_ID)/bin" || exit 0
	test -d src/wizards/$(WIZARD_ID)/rayZ-bin/ && cp -r src/wizards/$(WIZARD_ID)/rayZ-bin/* "build/$(TEMPLATES_DIR)/$(WIZARD_ID)/bin/" || exit 0
	test -d src/wizards/$(WIZARD_ID)/rayZ-bin/ && find "build/$(TEMPLATES_DIR)/$(WIZARD_ID)/bin" -type f  | xargs chmod 755 || exit 0
	saxonb-xslt -s:build/$(TEMPLATES_DIR)/$(WIZARD_ID)/xi-wizard.xml -xsl:"src/xsl/wizard.xsl" -o:"build/$(TEMPLATES_DIR)/$(WIZARD_ID)/wizard.py"
	perl -p -e "s|xxx-DOMAIN-xxx|$(WIZARD_ID)|g;s|xxx-LOCALEPATH-xxx|locale|g;" < src/i18n/rayZ_i18n.py > "build/$(TEMPLATES_DIR)/$(WIZARD_ID)/rayZ_i18n.py"
	
	mkdir -p "build/$(TEMPLATES_DIR)/locale/" && xgettext -o "build/$(TEMPLATES_DIR)/locale/$(WIZARD_ID).pot"   -L python --keyword=tr build/$(TEMPLATES_DIR)/$(WIZARD_ID)/*.py
	cp -r ./src/i18n/$(WIZARD_ID)/locale "build/$(TEMPLATES_DIR)/$(WIZARD_ID)/"

.PHONY: 

exec:
	$(PYTHON) build/$(TEMPLATES_DIR)/$(WIZARD)/wizard.py --write-json-file=build/$(WIZARD)/datamodel.json --session-manager=ray_control --start-gui-option  --debug

test-ray-control-template:
	$(PYTHON)  build/$(TEMPLATES_DIR)/$(WIZARD)/tmpl_wizard.py --rayZ-template-dir build/$(TEMPLATES_DIR)/$(WIZARD) --read-json-file=src/wizards/$(WIZARD)/test-data/datamodel.json --session-manager=ray_control $(TMPL_ARGS)

test-nsm-template:
	$(PYTHON)  build/$(TEMPLATES_DIR)/$(WIZARD)/tmpl_wizard.py --rayZ-template-dir build/$(TEMPLATES_DIR)/$(WIZARD) --read-json-file=src/wizards/$(WIZARD)/test-data/datamodel.json --session-manager=nsm $(TMPL_ARGS)

fill-template:
	$(PYTHON)  build/$(TEMPLATES_DIR)/$(WIZARD)/tmpl_wizard.py --rayZ-template-dir build/$(TEMPLATES_DIR)/$(WIZARD) --read-json-file=build/$(WIZARD)/datamodel.json $(TMPL_ARGS)

rayZ_wizards.py:
	cp src/rayZ_wizards.py build/rayZ_wizards.py
	perl -pi -e "s|xxx-DOMAIN-xxx|rayZ_wizards|g;s|xxx-LOCALEPATH-xxx|build/$(TEMPLATES_DIR)/locale|g;s|xxx-TEMPLATES_DIR-xxx|build/$(TEMPLATES_DIR)|g" build/rayZ_wizards.py
	mkdir -p "build/$(TEMPLATES_DIR)/locale/" && xgettext -o "build/$(TEMPLATES_DIR)/locale/rayZ_wizards.pot"   -L python --keyword=tr build/rayZ_wizards.py
	cp -r ./src/i18n/rayZ_wizards/locale "build/$(TEMPLATES_DIR)/"

exec-main: rayZ_wizards.py
	$(PYTHON) build/rayZ_wizards.py

install-catia:
	mkdir -p $(PREFIX)/bin
	install -m 755 src/bin/getwindidbyregexp $(PREFIX)/bin/getwindidbyregexp
	install -m 755 src/bin/getwindidbypid $(PREFIX)/bin/getwindidbypid
	install -m 755 src/bin/switchto $(PREFIX)/bin/switchto
	install -m 755 src/bin/switch-to-catia.sh $(PREFIX)/bin/switch-to-catia.sh

uninstall-catia:
	rm -f $(PREFIX)/bin/getwindidbyregexp
	rm -f $(PREFIX)/bin/getwindidbypid
	rm -f $(PREFIX)/bin/switchto
	rm -f $(PREFIX)/bin/switch-to-catia.sh
	
install-wrapper:
	install -m 755 src/bin/ray-config-session $(PREFIX)/bin/ray-config-session
	install -m 755 src/bin/nsm-config-session $(PREFIX)/bin/nsm-config-session

uninstall-wrapper:
	rm -rf $(PREFIX)/bin/ray-config-session
	rm -rf $(PREFIX)/bin/nsm-config-session

	
install: install-catia install-wrapper
	mkdir -p $(PREFIX)/$(TEMPLATES_DIR) $(PREFIX)/bin
	cp src/rayZ_wizards.py build/rayZ_wizards.py
	perl -pi -e "s|xxx-LOCALEPATH-xxx|$(PREFIX)/$(TEMPLATES_DIR)/locale|g;s|xxx-TEMPLATES_DIR-xxx|build/$(TEMPLATES_DIR)|g" build/rayZ_wizards.py
	install -m 755 build/rayZ_wizards.py $(PREFIX)/bin/rayZ_wizards
	cp -r build/$(TEMPLATES_DIR)/Jamulus $(PREFIX)/$(TEMPLATES_DIR)
	cp -r build/$(TEMPLATES_DIR)/simple_example $(PREFIX)/$(TEMPLATES_DIR)

	
uninstall: uninstall-catia uninstall-wrapper
	rm -f $(PREFIX)/bin/rayZ_wizards
	rm -rf $(PREFIX)/$(TEMPLATES_DIR)/Jamulus
	rm -rf $(PREFIX)/$(TEMPLATES_DIR)/simple_example
	
clean: 
	rm -rf build
	find -name "__pycache__" | xargs rm -rf 

prepare-i18n-ubuntu:
	sudo apt update
	sudo apt install gettext poedit
prepare-dev-ubuntu:
	sudo apt update
	sudo apt install git make build-essential gettext python3 python3-cheetah libxml2-utils python3-pyqt5 libsaxonb-java default-jre python3-lxml pyqt5-dev-tools qttools5-dev-tools qt5-default libjack-jackd2-dev
	
prepare-jamulus-ubuntu:
	sudo apt update
	sudo apt install netcat-openbsd calf-plugins guitarix papirus-icon-theme obs-studio obs-plugins

prepare-simple_example-ubuntu:
	sudo apt update
	sudo apt install alsaplayer-jack alsaplayer-common papirus-icon-theme
	
test-all:
	mkdir -p ~/NSM\ Sessions ~/Ray\ Sessions
	mkdir -p test && cd test && rm -rf Catia-fork rayZ-builder && git clone https://github.com/newlaurent62/rayZ-builder.git && git clone https://github.com/newlaurent62/Catia-fork.git
	cd test && rm -rf RaySession && git clone https://github.com/newlaurent62/RaySession.git
	cd test/RaySession && sudo make uninstall || exit 0
	cd test/RaySession && make clean && make && sudo make install
	cd test/rayZ-builder && sudo make uninstall || exit 0
	cd test/rayZ-builder && make clean && make && rm -rf ~/Ray\ Sessions/XFGHY_Jamulus && rm -rf ~/NSM\ Sessions/XFGHY_Jamulus && rm -rf ~/Ray\ Sessions/simple_example && rm -rf ~/NSM\ Sessions/simple_example && make WIZARD=Jamulus test-ray-control-template && make WIZARD=Jamulus test-nsm-template && make WIZARD=simple_example test-ray-control-template && make WIZARD=simple_example test-nsm-template && sudo make install
	cd test/Catia-fork && sudo make uninstall || exit 0
	cd test/Catia-fork && make && sudo make install

	killall catia || exit 0
	
# -----------------------------------------------------------------------------------------------------------------------------------------

debug:
	$(MAKE) DEBUG=false

# -----------------------------------------------------------------------------------------------------------------------------------------
