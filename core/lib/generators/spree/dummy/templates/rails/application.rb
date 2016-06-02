require File.expand_path('../boot', __FILE__)

require 'rails/all'

Bundler.require(*Rails.groups(assets: %w(development test)))

require '<%= lib_name %>'

<%= application_definition %>

