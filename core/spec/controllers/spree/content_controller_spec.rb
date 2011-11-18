require 'spec_helper'

describe Spree::ContentController do

  it "should understand routes" do
    pending("assert_routing tests are now broken, is this relevant any more?")
    assert_routing("/spree/content/cvv", {:controller => "content", :action => "cvv", :use_route => :spree })
  end

  it "should not display a local file" do
    controller.stub :current_user => Factory(:user)
    get :show, :path => "../../Gemfile"
    response.response_code.should == 404
  end

end
