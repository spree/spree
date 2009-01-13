require File.dirname(__FILE__) + "/autotest_helper"

describe Autotest::Rspec, "discovery" do
  it "adds the rspec autotest plugin" do
    Autotest.should_receive(:add_discovery)
    require File.dirname(__FILE__) + "/../../lib/autotest/discover"
  end
end  
