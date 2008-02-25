require "rubygems"

require 'test/unit'

require 'active_support'
require 'action_pack'
require 'action_controller'
require 'action_view'

require 'ostruct'

for file in ["../lib/calendar_date_select.rb", "../lib/includes_helper.rb"]
  require File.expand_path(File.join(File.dirname(__FILE__), file))
end

def dbg
  require 'ruby-debug'
  Debugger.start
  debugger
end

class Object
  def to_regexp
    is_a?(Regexp) ? self : Regexp.new(Regexp.escape(self.to_s))
  end
end