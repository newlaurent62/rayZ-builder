# raysession-wizard-builder
Tool to create a wizard that fill in a ray session template. 

The template engine used is cheetah (python3). It lets you use various flow control and variables.

1) You fill in an xml file then apply an xsl to generate the wizard in python.

2) you have to create three files:
for example with mywizard project:

- tmpl_mywizard.py                   # load the following two templates

- raysession_ray_control_sh.tmpl     # template using cheetah

- jack_connect_xml.tmpl              # template using cheetah


The mywizard example should give you a good start.

The wizard read mywizard.conf in the calling directory


## Test mywizard

to test the example:

$ make conf-mywizard

$ make mywizard

or

$ make

## Clean and uninstall raysession-template

$ make clean

