#!/usr/bin/make -f
# Makefile for code-generation #
# ---------------------- #
# Created by newlaurent62
#
PREFIX  = /.local
DESTDIR = /home/laurent
TEMPLATE_DIR = build/raysession-templates
PYTHON := /usr/bin/python3
DEFAULT_WIZARD := Jamulus
DEFAULT_PYTHON_FILES := $(patsubst %, %.py, $(wildcard src/wizards/$(DEFAULT_WIZARD)))
PYTHON_FILES := $(patsubst %, %.py, $(wildcard src/wizards/*))

# -----------------------------------------------------------------------------------------------------------------------------------------


all: install $(PYTHON_FILES)

build: install $(DEFAULT_PYTHON_FILES)

%.py : WIZARD_ID=$(patsubst src/wizards/%,%, $<)
%.py : %
	
	echo "--"
	echo -e "-- WIZARD_ID: \e[1m$(WIZARD_ID)\e[0m from $<"
	echo "--"
	
	mkdir -p build/$(WIZARD_ID)/xml build/$(WIZARD_ID)/raysession-template
	cp src/wizards/$(WIZARD_ID)/*.wizard src/wizards/$(WIZARD_ID)/pages/*.page src/wizards/$(WIZARD_ID)/snippets/*.tmpl_snippet build/$(WIZARD_ID)/xml/
	cheetah c -R --nobackup --idir src/wizards/$(WIZARD_ID)/tmpl --odir build/raysession-templates/$(WIZARD_ID)/

	mkdir -p build/raysession-templates/$(WIZARD_ID)/
	
	xmllint --xinclude --schema src/xsd/wizard.xsd build/$(WIZARD_ID)/xml/$(WIZARD_ID).wizard > build/raysession-templates/$(WIZARD_ID)/xi-wizard.xml
	java -cp ./libjava/Saxon-HE-9.9.1-5.jar net.sf.saxon.Transform -s:build/raysession-templates/$(WIZARD_ID)/xi-wizard.xml -xsl:"src/wizards/$(WIZARD_ID)/xsl/template-entry.xsl" -o:"build/raysession-templates/$(WIZARD_ID)/tmpl_wizard.py"
	java -cp ./libjava/Saxon-HE-9.9.1-5.jar net.sf.saxon.Transform -s:build/raysession-templates/$(WIZARD_ID)/xi-wizard.xml -xsl:"src/wizards/$(WIZARD_ID)/xsl/wizard.xsl" -o:"build/raysession-templates/$(WIZARD_ID)/wizard.py"
	perl -pi -e "s|xxx-TEMPLATE_DIR-xxx|$(TEMPLATE_DIR)/$(WIZARD_ID)|g" "build/raysession-templates/$(WIZARD_ID)/tmpl_wizard.py" "build/raysession-templates/$(WIZARD_ID)/wizard.py"
	java -cp ./libjava/Saxon-HE-9.9.1-5.jar net.sf.saxon.Transform -s:build/raysession-templates/$(WIZARD_ID)/xi-wizard.xml -xsl:"src/wizards/$(WIZARD_ID)/xsl/install.xsl" -o:"build/raysession-templates/$(WIZARD_ID)/install_dep_wizard.sh"
	java -cp ./libjava/Saxon-HE-9.9.1-5.jar net.sf.saxon.Transform -s:build/raysession-templates/$(WIZARD_ID)/xi-wizard.xml -xsl:"src/wizards/$(WIZARD_ID)/xsl/info-template.xsl" -o:"build/raysession-templates/$(WIZARD_ID)/info_wizard.xml"
	java -cp ./libjava/Saxon-HE-9.9.1-5.jar net.sf.saxon.Transform -s:build/raysession-templates/$(WIZARD_ID)/xi-wizard.xml -xsl:"src/wizards/$(WIZARD_ID)/xsl/raysession_xml-gen_tmpl.xsl" -o:"build/raysession-templates/$(WIZARD_ID)/raysession_xml.tmpl"
	java -cp ./libjava/Saxon-HE-9.9.1-5.jar net.sf.saxon.Transform -s:build/raysession-templates/$(WIZARD_ID)/xi-wizard.xml -xsl:"src/wizards/$(WIZARD_ID)/xsl/raysession_sh-gen_tmpl.xsl" -o:"build/raysession-templates/$(WIZARD_ID)/raysession_sh.tmpl"
	java -cp ./libjava/Saxon-HE-9.9.1-5.jar net.sf.saxon.Transform -s:build/raysession-templates/$(WIZARD_ID)/xi-wizard.xml -xsl:"src/wizards/$(WIZARD_ID)/xsl/patch_xml-gen_tmpl.xsl" -o:"build/raysession-templates/$(WIZARD_ID)/patch_xml.tmpl"
	
	[ -f "src/wizards/$(WIZARD_ID)/xsl/ray_script_load_sh-gen_tmpl.xsl" ] && java -cp ./libjava/Saxon-HE-9.9.1-5.jar net.sf.saxon.Transform -s:build/raysession-templates/$(WIZARD_ID)/xi-wizard.xml -xsl:"src/wizards/$(WIZARD_ID)/xsl/ray_script_load_sh-gen_tmpl.xsl" -o:"build/raysession-templates/$(WIZARD_ID)/ray_script_load_sh.tmpl" || exit 0


	cheetah c -R --nobackup --idir "build/raysession-templates/$(WIZARD_ID)" --odir "build//raysession-templates/$(WIZARD_ID)"
	mkdir -p "build/raysession-templates/$(WIZARD_ID)/bin" "build/raysession-templates/$(WIZARD_ID)/default" "build/raysession-templates/$(WIZARD_ID)/share" "build/raysession-templates/$(WIZARD_ID)/data"
	cp -r src/gui/* src/wizards/$(WIZARD_ID)/default "build/raysession-templates/$(WIZARD_ID)/"
	[ -d src/wizards/$(WIZARD_ID)/ray-scripts ] && cp -r src/wizards/$(WIZARD_ID)/ray-scripts "build/raysession-templates/$(WIZARD_ID)/"

.PHONY: 

exec:
	$(PYTHON) build/raysession-templates/$(DEFAULT_WIZARD)/wizard.py --write-json-file=build/$(DEFAULT_WIZARD)/datamodel.json --start-gui-option

test-template:
	$(PYTHON)  build/raysession-templates/$(DEFAULT_WIZARD)/tmpl_wizard.py --read-json-file=src/wizards/$(DEFAULT_WIZARD)/test-data/datamodel.json
	
fill-template:
	$(PYTHON)  build/raysession-templates/$(DEFAULT_WIZARD)/tmpl_wizard.py --read-json-file=build/$(DEFAULT_WIZARD)/datamodel.json --start-gui

install:
	mkdir -p ~/.local/bin
	cp src/bin/alt-config-session ~/.local/bin/alt-config-session

uninstall:
	rm -f ~/.local/bin/alt-config-session

clean: uninstall
	rm -rf build
	find -name "__pycache__" | xargs rm -rf 
	
prepare-ubuntu:
	echo "-- Instructions on ubuntu 20.04"
	sudo apt install python3-cheetah libxml2-utils yad python3-pyqt5
	
# -----------------------------------------------------------------------------------------------------------------------------------------

debug:
	$(MAKE) DEBUG=false

# -----------------------------------------------------------------------------------------------------------------------------------------
