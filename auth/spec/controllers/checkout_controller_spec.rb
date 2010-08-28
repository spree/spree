require 'spec_helper'

describe CheckoutController do
  let(:order) { Order.new }

  before do
    order.stub :checkout_allowed? => true
    controller.stub :current_order => order
  end

  context "#update" do
    it "should check if user is authorized for :edit" do
      controller.should_receive(:authorize!).with(:edit, order)
      post :update, { :state => "confirm", :order => {} }
    end
  end

  context "#edit" do
    it "should check if user is authorized for :edit" do
      controller.should_receive(:authorize!).with(:edit, order)
      get :edit, { :state => "confirm", :order => {} }
    end
  end
end