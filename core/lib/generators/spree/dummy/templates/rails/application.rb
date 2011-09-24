require File.expand_path('../boot', __FILE__)

require 'rails/all'

Bundler.require(Rails.env)

require '<%= lib_name %>'

<%= application_definition %>

