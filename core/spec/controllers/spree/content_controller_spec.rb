require 'spec_helper'

describe Spree::ContentController do
  it "should not display a local file" do
    spree_get :show, :path => "../../Gemfile"
    response.response_code.should == 404
  end

  it "should display CVV page" do
    spree_get :cvv
    response.response_code.should == 200
  end
end
