require 'spec_helper'

describe 'tracking current IP address for orders' do
  controller(Spree::StoreController) do
    def index
      render :nothing => true
    end
  end

  let(:order) { FactoryGirl.create(:order) }

  it 'is done automatically when current_order is called' do
    get :index, {}, { :order_id => order.id }
    controller.current_order.last_ip_address.should == "0.0.0.0"
  end
end
