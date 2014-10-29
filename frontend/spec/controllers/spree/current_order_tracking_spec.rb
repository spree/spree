require 'spec_helper'

describe 'current order tracking', :type => :controller do
  let(:user) { create(:user) }

  controller(Spree::StoreController) do
    def index
      render :nothing => true
    end
  end

  let(:order) { FactoryGirl.create(:order) }

  it 'automatically tracks who the order was created by & IP address' do
    allow(controller).to receive_messages(:try_spree_current_user => user)
    get :index
    expect(controller.current_order(create_order_if_necessary: true).created_by).to eq controller.try_spree_current_user
    expect(controller.current_order.last_ip_address).to eq "0.0.0.0"
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
