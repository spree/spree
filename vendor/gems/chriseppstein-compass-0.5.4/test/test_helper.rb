# allows testing with edge Rails by creating a test/rails symlink
RAILS_ROOT = linked_rails = File.dirname(__FILE__) + '/rails'
RAILS_ENV = 'test'

need_gems = false
if File.exists?(linked_rails) && !$:.include?(linked_rails + '/activesupport/lib')
  puts "[ using linked Rails ]"
  $:.unshift linked_rails + '/activesupport/lib'
  $:.unshift linked_rails + '/actionpack/lib'
else
  need_gems = true
end

# allows testing with edge Haml by creating a test/haml symlink
linked_haml = File.dirname(__FILE__) + '/haml'

if File.exists?(linked_haml) && !$:.include?(linked_haml + '/lib')
  puts "[ using linked Haml ]"
  $:.unshift linked_haml + '/lib'
else
  need_gems = true
end

require 'rubygems' if need_gems

require 'action_controller'
require 'action_view'
require 'haml'
require 'sass'
require 'sass/plugin'


require 'test/unit'

module Compass
  module TestCaseHelper
    def absolutize(path)
      if path.blank?
        File.dirname(__FILE__)
      elsif path[0] == ?/
        "#{File.dirname(__FILE__)}#{path}"
      else
        "#{File.dirname(__FILE__)}/#{path}"
      end
    end
  end
end
