require "spec_helper"
require "cancan"
require "spree/testing_support/bar_ability"

describe Spree::Admin::Orders::CustomerDetailsController, type: :controller do

  context "with authorization" do
    stub_authorization!

    let(:order) do
      mock_model(
        Spree::Order,
        total:           100,
        number:          "R123456789",
        billing_address: mock_model(Spree::Address)
      )
    end

    before do
      allow(Spree::Order).to receive_message_chain(:friendly, :find).and_return(order)
    end

    context "#update" do
      it "does refresh the shipment rates with all shipping methods" do
        allow(order).to receive_messages(update_attributes: true)
        allow(order).to receive_messages(next: false)
        expect(order).to receive(:refresh_shipment_rates)
          .with(Spree::ShippingMethod::DISPLAY_ON_FRONT_AND_BACK_END)
        attributes = {
          order_id: order.number,
          order: {
            email: "",
            use_billing: "",
            bill_address_attributes: {},
            ship_address_attributes: {}
          }
        }
        spree_put :update, attributes
      end
    end
  end
end
