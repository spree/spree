# allows testing with edge Rails by creating a test/rails symlink
linked_rails = File.dirname(__FILE__) + '/rails'

if File.exists?(linked_rails) && !$:.include?(linked_rails + '/activesupport/lib')
  puts "[ using linked Rails ]"
  $:.unshift linked_rails + '/activesupport/lib'
  $:.unshift linked_rails + '/actionpack/lib'
else
  require 'rubygems'
end
require 'action_controller'
require 'action_view'
