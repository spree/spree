require File.dirname(__FILE__) + '/../spec_helper'

describe ContentController do

  it "should understand routes" do
    assert_routing("/content/cvv", {:controller => "content", :action => "cvv", })
  end

  it "should not display a local file" do
    get :show, :path => "../../Gemfile"
    response.response_code.should == 404
  end

end
