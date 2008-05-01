require File.dirname(__FILE__) + '/story_helper'

require 'spec/story'

describe Kernel, "#Story" do
  before(:each) do
    Kernel.stub!(:at_exit)
  end

  it "should delegate to ::Spec::Story::Runner.story_runner" do
    ::Spec::Story::Runner.story_runner.should_receive(:Story)
    story = Story("title","narrative"){}
  end
end
