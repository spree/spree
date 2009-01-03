require 'spec/story'
require File.dirname(__FILE__) + '/../../../spec/ruby_forker'

module StoryHelper
  include RubyForker

  def spec(args, stderr)
    ruby("#{File.dirname(__FILE__) + '/../../../bin/spec'} #{args}", stderr)
  end

  def cmdline(args, stderr)
    ruby("#{File.dirname(__FILE__) + '/../../resources/helpers/cmdline.rb'} #{args}", stderr)
  end
  
  Spec::Story::World.__send__ :include, self
end
