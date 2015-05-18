require 'spec_helper'

describe 'current order tracking', :type => :controller do
  let(:user) { create(:user) }

  controller(Spree::StoreController) do
    def index
      render :nothing => true
    end
  end

  let(:order) { create(:order) }

  it 'automatically tracks who the order was created by & IP address' do
    allow(controller).to receive_messages(:try_spree_current_user => user)
    get :index
    expect(controller.cart_order.created_by).to eql(controller.try_spree_current_user)
    expect(controller.cart_order.last_ip_address).to eql('0.0.0.0')
  end

  context "current order creation" do
    before { allow(controller).to receive_messages(:try_spree_current_user => user) }

    it "doesn't create a new order out of the blue" do
      expect {
        spree_get :index
      }.not_to change { Spree::Order.count }
    end
  end
end

describe Spree::OrdersController, :type => :controller do
  let(:user) { create(:user) }

  before { allow(controller).to receive_messages(:try_spree_current_user => user) }

  describe Spree::OrdersController do
    it "doesn't create a new order out of the blue" do
      expect {
        spree_get :edit
      }.not_to change { Spree::Order.count }
    end
  end
end
