require 'spec_helper'
require 'cancan'
require 'spree/testing_support/bar_ability'

# Ability to test access to specific model instances
# class OrderSpecificAbility
#   include CanCan::Ability

#   def initialize(user)
#     can [:admin, :manage], Spree::Order, :number => 'R987654321'
#   end
# end

describe Spree::Admin::Orders::CustomerDetailsController, :type => :controller do

  context "with authorization" do
    stub_authorization!

    let(:order) do
      mock_model(
        Spree::Order,
        total:           100,
        number:          'R123456789',
        billing_address: mock_model(Spree::Address)
      )
    end

    before do
      allow(Spree::Order).to receive_messages(find_by_number!: order)
    end

    context "#update" do
      it "does refresh the shipment rates with all shipping methods" do
        allow(order).to receive_messages :update_attributes => true
        allow(order).to receive_messages :next => false
        expect(order).to receive(:refresh_shipment_rates).with(false)
        attributes = {
          :order_id => order.number,
          :order => {
            :email => '',
            :use_billing => '',
            :bill_address_attributes => {},
            :ship_address_attributes => {}
          }
        }
        spree_put :update, attributes
      end
    end
  end
end
