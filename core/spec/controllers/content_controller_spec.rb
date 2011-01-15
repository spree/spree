require File.dirname(__FILE__) + '/../spec_helper'

describe ContentController do

  it "should understand routes" do
    assert_routing("/content/cvv", {:controller => "content", :action => "cvv", })
  end

end
