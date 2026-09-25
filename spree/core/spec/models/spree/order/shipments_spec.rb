require 'spec_helper'

describe Spree::Order, type: :model do
  let(:order) { create(:order_with_totals) }

  context 'ensure shipments will be updated' do
    before { Spree::Shipment.create!(order: order, stock_location: create(:stock_location)) }

    context "except when order is completed, that's OrderInventory job" do
      it "doesn't touch anything" do
        allow(order).to receive_messages completed?: true
        order.update_column(:shipment_total, 5)
        order.shipments.create!(stock_location: create(:stock_location))

        expect do
          order.ensure_updated_fulfillments
        end.not_to change(order, :shipment_total)

        expect do
          order.ensure_updated_fulfillments
        end.not_to change(order, :shipments)
      end
    end
  end
end
