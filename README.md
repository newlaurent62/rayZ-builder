# rayZ-builder

Tool to create wizards to fill ray session templates. 

The template engine used is cheetah (python3). It lets you use various flow controls and variables.

You might need XML, XSL, bash, Cheetah (python related) programming skills.

if your use case is simple, then you only need to fill one XML file and to create three Cheetah templates (ray_session_sh, ray_session_xml, patch_xml).

## Try the wizards

make : generates all wizards

make build : generates DEFAULT_WIZARD

make exec : start the DEFAULT_WIZARD wizard

make test-template : fill the DEFAULT_WIZARD template using test-data

make fill-template : fill the DEFAULT_WIZARD template and start raysession gui

make install : install the script wrapper needed to start client in the created raysession

make uninstall : uninstall the script wrapper 

## Clean and uninstall raysession-template

$ make clean

