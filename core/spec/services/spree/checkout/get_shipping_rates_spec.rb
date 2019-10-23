require 'spec_helper'

module Spree
  describe Checkout::GetShippingRates do
    subject { described_class }

    let(:order) { create(:order) }
    let(:line_item) { create(:line_item, order: order) }
    let(:shipment) { order.reload.shipments.first }

    let(:execute) { subject.call(order: order) }
    let(:value) { execute.value }
    let(:error) { execute.error.to_s }

    let!(:country) { create(:country) }
    let!(:shipping_method) do
      create(:shipping_method).tap do |shipping_method|
        shipping_method.calculator.preferred_amount = 10
        shipping_method.calculator.save
        shipping_method.zones = [zone]
      end
    end
    let!(:zone) { create(:zone) }
    let!(:zone_member) { create(:zone_member, zone: zone, zoneable: country) }
    let(:address) { create(:address, country: country) }

    let(:free_shipping_promotion) { create(:free_shipping_promotion) }

    shared_examples 'generates shipping rates' do
      it 'returns shipping rates' do
        expect(execute.success?).to eq(true)
        expect(value).not_to be_empty
        expect(value).to eq(order.reload.shipments)
        expect(shipment.shipping_method).to eq(shipping_method)
      end

      it "doesn't update checkout state" do
        expect { execute }.not_to change {
          order.state
          order.completed_at
        }
      end
    end

    shared_examples 'applies standard shipping costs' do
      before { execute }

      it 'for shipment' do
        expect(shipment.final_price).to eq(10.0)
      end

      it 'updates shipment total' do
        expect(order.reload.shipment_total).to eq(10.0)
      end
    end

    shared_examples 'failure' do
      it 'returns error' do
        expect(execute.success?).to eq(false)
        expect(value).to be_empty
        expect(error).to eq(error_message)
      end

      it "doesn't generate shipping rates" do
        expect { execute }.not_to change {
          Spree::ShippingRate.count
          order.shipments
          order.state
          order.completed_at
        }
      end
    end

    context 'without shipping address' do
      let(:error_message) { 'To generate Shipping Rates Order needs to have a Shipping Address' }

      it_behaves_like 'failure'
    end

    context 'without line items' do
      let(:error_message) { 'To generate Shipping Rates you need to add some Line Items to Order' }

      before do
        order.ship_address = address
        order.save!
      end

      it_behaves_like 'failure'
    end

    context 'with line items and shipping address' do
      before do
        line_item
        order.ship_address = address
        order.save!
      end

      context 'without shipments' do
        before { order.shipments.destroy_all }

        it_behaves_like 'generates shipping rates'
        it_behaves_like 'applies standard shipping costs'
      end

      context 'with already present shipments' do
        it_behaves_like 'generates shipping rates'
        it_behaves_like 'applies standard shipping costs'

        it 'replaces current shipments with new ones' do
          expect { execute }.to change { order.shipments.pluck(:number) }
        end
      end

      context 'with free shipping promotion' do
        before do
          free_shipping_promotion
          execute
        end

        it 'applies promotion' do
          expect(order.promotions).to include(free_shipping_promotion)
          expect(shipment.final_price).to eq(0.0)
        end
      end
    end
  end
end
