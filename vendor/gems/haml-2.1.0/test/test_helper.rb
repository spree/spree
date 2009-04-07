lib_dir = File.dirname(__FILE__) + '/../lib'
require File.dirname(__FILE__) + '/linked_rails'

require 'test/unit'
$:.unshift lib_dir unless $:.include?(lib_dir)
require 'haml'
require 'sass'

# required because of Sass::Plugin
unless defined? RAILS_ROOT
  RAILS_ROOT = '.'
  MERB_ENV = RAILS_ENV  = 'testing'
end

class Test::Unit::TestCase
  def munge_filename(opts)
    return if opts[:filename]
    test_name = caller[1].gsub(/^.*`(?:\w+ )*(\w+)'.*$/, '\1')
    opts[:filename] = "#{test_name}_inline.sass"
  end
end
