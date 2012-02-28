require 'spec_helper'

describe ContentController do
  before do
    controller.stub :current_user => Factory(:user)
  end


  it "should understand routes" do
    assert_routing("/content/cvv", {:controller => "content", :action => "cvv", })
  end

  it "should not display a local file" do
    get :show, :path => "../../Gemfile"
    response.response_code.should == 404
  end

end
