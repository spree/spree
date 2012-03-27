require 'spec_helper'

module Spree
  describe Api::V1::LineItemsController do
    let!(:order) { Factory(:order) }
    let(:product) { Factory(:product) }
    let(:attributes) { [:quantity, :variant_id] }

    let(:resource_scoping) { { :order_id => order.to_param } }

    before do
      stub_authentication!
    end

    it "can learn how to create a new line item"

    it "can add a new line item to an existing order" do
      api_post :create, :line_item => { :variant_id => product.master.to_param, :quantity => 1 }
      response.status.should == 201
      json_response.should have_attributes(attributes)
    end

    it "cannot add a new line item to an order that doesn't belong to them"

  end
end
