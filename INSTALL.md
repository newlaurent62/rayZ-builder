# INSTALL.md

## Setup development environment

To prepare your ubuntu (tested on 20.04) :

    make prepare-dev-ubuntu

It will install all required development packages.


## Install softwares used by rayZ wizards

### Jamulus wizards (complex virtual studio conf)

Packaged:
    
    make prepare-jamulus-ubuntu
    
### simple_example (simple virtual studio conf)
    
    make prepare-simple_example-ubuntu

## [un]Install rayZ scripts 

You can install rayZ-builder in your home directory rather than in usr:

    make install PREFIX=~/.local
    
You can also install in /usr or /usr/local:
    
    make install PREFIX=/usr/local

or configure your PREFIX in the makefile:

    make install
    
to uninstall it:
  
    make uninstall


