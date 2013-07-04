# encoding: utf-8
require 'spec_helper'

# This spec is useful for when we just want to make sure a view is rendering correctly
# Walking through the entire checkout process is rather tedious, don't you think?
describe Spree::CheckoutController do
  render_views
  let(:token) { 'some_token' }
  let(:user) { stub_model(Spree::LegacyUser) }

  before do
    controller.stub :try_spree_current_user => user
  end

  # Regression test for #3246
  context "when using GBP" do
    before do
      Spree::Config[:currency] = "GBP"
    end

    context "when order is in delivery" do
      before do
        # Using a let block won't acknowledge the currency setting
        # Therefore we just do it like this...
        order = OrderWalkthrough.up_to(:address)
        controller.stub :current_order => order
      end

      it "displays rate cost in correct currency" do
        spree_get :edit
        html = Nokogiri::HTML(response.body)
        html.css('.rate-cost').text.should == "£10.00"
      end
    end
  end
end