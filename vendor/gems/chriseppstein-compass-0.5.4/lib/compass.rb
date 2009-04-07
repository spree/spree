require 'rubygems'
require 'sass'

def assert_sass_version(obj)
  unless obj.respond_to?(:version) && obj.version[:major] == 2 && obj.version[:minor] >= 1
    raise LoadError.new("Compass requires Haml version 2.1 or greater.")
  end
end

begin
  assert_sass_version(Sass)
rescue LoadError
  require 'haml'
  assert_sass_version(Haml)
end

require File.join(File.dirname(__FILE__), 'sass_extensions')

['core_ext', 'version'].each do |file|
  require File.join(File.dirname(__FILE__), 'compass', file)
end

module Compass
  extend Compass::Version
  def base_directory
    File.expand_path(File.join(File.dirname(__FILE__), '..'))
  end
  def lib_directory
    File.expand_path(File.join(File.dirname(__FILE__)))
  end
  module_function :base_directory, :lib_directory
end

require File.join(File.dirname(__FILE__), 'compass', 'configuration')
require File.join(File.dirname(__FILE__), 'compass', 'frameworks')

# make sure we're running inside Merb
require File.join(File.dirname(__FILE__), 'compass', 'merb') if defined?(Merb::Plugins)  

