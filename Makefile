#!/usr/bin/make -f
# Makefile for code-generation #
# ---------------------- #
# Created by newlaurent62
#
PREFIX  = /.local
DESTDIR = ~
TMPL_RAY := $(DESTDIR)$(PREFIX)/share/raysession-templates
PYTHONPATH=src/gui/:./build:$PYTHONPATH

PYTHON := /usr/bin/python3

LRELEASE := lrelease
ifeq (, $(shell which $(LRELEASE)))
 LRELEASE := lrelease-qt5
endif

ifeq (, $(shell which $(LRELEASE)))
 LRELEASE := lrelease-qt4
endif

# -----------------------------------------------------------------------------------------------------------------------------------------

all: mywizard

mywizard: clean-mywizard generate-mywizard prepare-mywizard exec-mywizard 

conf-mywizard:
	cp src/conf/mywizard.conf ./
	
generate-mywizard:
	xmllint --schema src/xsd/wizard.xsd src/xml/mywizard.xml --noout
	java -cp ./libjava/Saxon-HE-9.9.1-5.jar net.sf.saxon.Transform -s:"./src/xml/mywizard.xml" -xsl:"./src/xsl/wizard.xsl" -o:"./build/mywizard.py"
	cheetah c -R --idir src/templates/mywizard --odir build
	mkdir -p $(TMPL_RAY)
	cp -r src/templates/mywizard $(TMPL_RAY)/

prepare-mywizard:	
	cp -r src/gui/* build/
	cp -r src/templates/* build/
	mkdir -p ~/.local/bin/
	cp src/bin/alt-config-session ~/.local/bin/alt-config-session

exec-mywizard:
	$(PYTHON) build/mywizard.py $(TMPL_RAY)

clean-mywizard:
	rm -rf ./build
	rm -f -R src/__pycache__ src/*/__pycache__ src/*/*/__pycache__
	rm -f ~/.local/bin/alt-config-session
	rm -rf $(TMPL_RAY)/mywizard
	
clean-conf-mywizard:
	rm -f mywizard.conf
	

clean: clean-mywizard

clean-conf: clean-conf-mywizard

clean-all: clean clean-conf

prepare-ubuntu:
	echo "-- Instructions on ubuntu 20.04"
	sudo apt install python3-cheetah libxml2-utils
	
# -----------------------------------------------------------------------------------------------------------------------------------------

debug:
	$(MAKE) DEBUG=true

# -----------------------------------------------------------------------------------------------------------------------------------------
