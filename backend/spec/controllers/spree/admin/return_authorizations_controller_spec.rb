require 'spec_helper'

describe Spree::Admin::ReturnAuthorizationsController, :type => :controller do
  stub_authorization!

  # Regression test for #1370 #3
  let!(:order) { create(:order) }
  it "can create a return authorization" do
    spree_post :create, :order_id => order.to_param, :return_authorization => { :amount => 0.0, :reason => "" }
    expect(response).to be_success
  end
end
