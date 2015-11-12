require 'spec_helper'

module Spree
  describe Api::ConfigController, :type => :controller do
    render_views

    before do
      stub_authentication!
    end

    it "returns Spree::Money settings" do
      api_get :money
      expect(response).to be_success
      expect(json_response["symbol"]).to eq("$")
      expect(json_response["symbol_position"]).to eq("before")
      expect(json_response["no_cents"]).to eq(false)
      expect(json_response["decimal_mark"]).to eq(".")
      expect(json_response["thousands_separator"]).to eq(",")
    end

    it "returns some configuration settings" do
      api_get :show
      expect(response).to be_success
      expect(json_response["default_country_id"]).to eq(Spree::Config[:default_country_id])
    end
  end
end
