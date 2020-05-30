# rayZ-builder

This tool let you create simple or complex virtual studio setup.

These virtual studio called session, let you save or close all audio applications in one click.

rayZ-builder is compatible with:
  - non-session-manager (a fast and reliable session manager)
  - raysession (compatible with non-session-manager. It adds some useful features)

The purpose of rayZ-builder is to create wizards that fill templates to create a session documents.

It uses declarative XML files and cheetah template engine.

Once walking through the wizard steps and validated the inputs, those inputs are passed to the template to create the final session document.

## Try the wizards

Create all the wizards:

    make 

Main window, let you start one of the wizards available in the install dir. 

rayZ wizards can be added at any time in the install dir. They will be recognized.

    make exec-main
    
Compile only one wizard you are developping:
    
    make build WIZARD=mywizard

    make exec WIZARD=mywizard
    
You can also set the WIZARD variable in the Makefile rather than set the variable from command line.

## Fill the templates

test-data are in the src directory located in subdir test-data of the wizard dir.

Ex: src/wizards/mywizard/test-data

fill the $(WIZARD) template from test-data inputs to generate a ray session with ray_control.

    make test-ray-control-template

fill the $(WIZARD) template from test-data inputs to generate a ray session without ray_control.
    
    make test-ray-xml-template

fill the $(WIZARD) template from test-data inputs to generate an nsm session.

    make test-nsm-template

## Install / Uninstall wrapper scripts

install the main script and script wrappers needed to use the session documents generated by rayZ-builder

    make install-wrapper 

uninstall main script and script wrappers

    make uninstall-wrapper

## Clean

    make clean

