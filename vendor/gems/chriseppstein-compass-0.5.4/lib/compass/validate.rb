#!/usr/bin/env ruby
require File.join(File.dirname(__FILE__), 'compass', 'validator')

# This script will validate the core Compass files. 
# 
# The files are not completely valid. This has to do 
# with a small number of CSS hacks needed to ensure 
# consistent rendering across browsers.
#
# To add your own CSS files for validation, see
# /lib/compass/validator.rb

Compass::Validator.new.validate