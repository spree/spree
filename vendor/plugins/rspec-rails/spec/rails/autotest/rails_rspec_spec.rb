require File.dirname(__FILE__) + '/../../spec_helper'
require File.join(File.dirname(__FILE__), "..", "..", "..", "lib", "autotest", "rails_rspec")

describe Autotest::RailsRspec do
  it "should provide the correct spec_command" do
    Autotest::RailsRspec.new.spec_command.should == "script/spec"
  end
end
