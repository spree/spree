$:.unshift File.join(File.dirname(__FILE__), '..', '..', 'lib')
require 'spec/story'

# won't have to do this once plain_text_story_runner is moved into the library
# require File.join(File.dirname(__FILE__), "plain_text_story_runner")

Dir[File.join(File.dirname(__FILE__), "steps/*.rb")].each do |file|
  require file
end