$LOAD_PATH.unshift File.expand_path("#{File.dirname(__FILE__)}/../lib")
require 'spec'
require 'tempfile'
require File.join(File.dirname(__FILE__), *%w[resources matchers smart_match])
require File.join(File.dirname(__FILE__), *%w[resources helpers story_helper])
require File.join(File.dirname(__FILE__), *%w[resources steps running_rspec])
