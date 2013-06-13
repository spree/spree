require 'spec_helper'

module Spree
  describe Api::ConfigController do
    render_views

    before do
      stub_authentication!
    end

    it "returns Spree::Money settings" do
      api_get :money
      response.should be_success
      json_response["symbol"].should == "$"
      json_response["symbol_position"].should == "before"
      json_response["no_cents"].should == false
      json_response["decimal_mark"].should == "."
      json_response["thousands_separator"].should == ","
    end
  end
end