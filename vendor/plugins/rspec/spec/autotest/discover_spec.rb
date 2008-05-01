require File.dirname(__FILE__) + "/../autotest_helper"

module DiscoveryHelper
  def load_discovery
    require File.dirname(__FILE__) + "/../../lib/autotest/discover"
  end
end


class Autotest
  describe Rspec, "discovery" do
    include DiscoveryHelper
    
    it "should add the rspec autotest plugin" do
      Autotest.should_receive(:add_discovery).and_yield
      load_discovery
    end
  end  
end
