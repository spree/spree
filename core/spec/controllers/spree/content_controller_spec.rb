require 'spec_helper'

describe Spree::ContentController do

  it "should not display a local file" do
    controller.stub :current_user => Factory(:user)
    get :show, :path => "../../Gemfile"
    response.response_code.should == 404
  end

end
