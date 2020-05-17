# TODO

## mywizard example

  - jack_capture auto connects to pulseaudio when starting in ray_control : why ?
  
  - When creating the raysession document, jack_capture create a wav file in the current directory : avoid that.
  

## Overall 

- Create a DTD or schema that allow for XML checking before applying XSL stylesheet to create the wizard python code.
  in progress

- actually the template can be tested only after walking through the wizard steps
   => create a command line to test the template from JSON datamodel generated once by the wizard

- make a declarative template mechanism 
  only XML code needed + Cheetah template (no need for python code)

- documentation

- use client-proxy ?
