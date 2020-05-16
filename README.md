# raysession-wizard-builder
Tool to create a wizard that fill in a ray session template. 

The template engine used is cheetah (python3). It lets you use various flow control and variables.

You fill in an xml file then apply an xsl to generate the wizard in python.

Then you have to create three files:
for example with mywizard project:
- tmpl_mywizard.py                   # load the following two templates
- raysession_ray_control_sh.tmpl     # template using cheetah
- jack_connect_xml.tmpl              # template using cheetah

The wizard read mywizard.conf in the calling directory

to test an example:
$ make mywizard

or

$ make

to call the default wizard configuration
$ make mywizard-conf

to uninstall and clean the wizard
$ make clean

