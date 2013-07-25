require 'spec_helper'

describe 'current order tracking' do
  controller(Spree::StoreController) do
    def index
      render :nothing => true
    end
  end

  let(:order) { FactoryGirl.create(:order) }

  it 'automatically tracks IP when current_order is called' do
    get :index, {}, { :order_id => order.id }
    controller.current_order.last_ip_address.should == "0.0.0.0"
  end

  it 'automatically tracks who the order was created by' do
    user = FactoryGirl.create(:user)
    controller.stub(:try_spree_current_user => user)
    get :index
    controller.current_order.created_by.should == controller.try_spree_current_user
  end
end
