require 'spec_helper'

module Spree
  describe Checkout::SelectShippingMethod do
    subject { described_class }

    let(:country) { create(:country) }
    let(:store) { create(:store, checkout_zone: zone) }
    let(:order) { create(:order_with_totals, store: store, ship_address: create(:address, country: country)) }

    let(:execute) { subject.call(order: order, params: params) }
    let(:value) { execute.value }

    let(:params) do
      {
        shipping_method_id: shipping_method_2.id
      }
    end
    let(:zone) { create(:zone_with_country) }
    let(:shipping_category) { order.products.first.shipping_category }
    let!(:shipping_method) do
      create(:shipping_method, zones: [zone], shipping_categories: [shipping_category]) do |shipping_method|
        shipping_method.calculator.preferred_amount = 10
        shipping_method.calculator.save
      end
    end
    let!(:shipping_method_2) do
      create(:shipping_method, zones: [zone], shipping_categories: [shipping_category]) do |shipping_method|
        shipping_method.calculator.preferred_amount = 15
        shipping_method.calculator.save
      end
    end
    let!(:shipping_method_3) do
      create(:shipping_method, zones: [create(:zone)], shipping_categories: [shipping_category]) do |shipping_method|
        shipping_method.calculator.preferred_amount = 5
        shipping_method.calculator.save
      end
    end
    let(:shipment) { order.shipments.last }
    let(:selected_shipping_rate) { shipment.selected_shipping_rate }

    before do
      zone.countries << country
    end

    context 'one shipment' do
      before do
        Spree::Checkout::GetShippingRates.call(order: order)
        order.reload
      end

      context 'valid shipping method' do
        it { expect(execute.success?).to eq(true) }
        it { expect(execute.value).to be_kind_of(Spree::Order) }
        it { expect(execute.value.id).to eq(order.id) }

        it 'sets selected shipping method for shipment' do
          expect(shipment.shipping_rates.count).to eq(2)
          execute
          expect(selected_shipping_rate.shipping_method).to eq(shipping_method_2)
        end
      end

      context 'missing shipping method' do
        let(:params) do
          {
            shipping_method_id: shipping_method_3.id
          }
        end

        it { expect(execute.success?).to eq(false) }
        it { expect(execute.value).to eq(:selected_shipping_method_not_found) }
        it { expect(execute.error.to_s).to match(/Couldn't find shipping rate/) }
      end
    end

    context 'multiple shipments' do
      let(:product_2) { create(:product_in_stock, shipping_category: shipping_category) }
      let!(:line_item) { create(:line_item, variant: product_2.master, order: order) }

      let(:shipment) { order.shipments.first }
      let(:shipment_2) { order.shipments.last }

      before do
        Spree::Checkout::GetShippingRates.call(order: order)
        order.reload
      end

      context 'update selected shipment' do
        let(:params) do
          {
            shipment_id: shipment_2.id,
            shipping_method_id: shipping_method_2.id
          }
        end

        it { expect(execute.success?).to eq(true) }

        it 'sets selected shipping method for the specified shipment' do
          expect(order.shipments.count).to eq(2)
          expect(shipment.selected_shipping_rate.shipping_method).to eq(shipping_method)
          expect(shipment_2.selected_shipping_rate.shipping_method).to eq(shipping_method)
          execute
          expect(shipment.reload.selected_shipping_rate.shipping_method).to eq(shipping_method)
          expect(shipment_2.reload.selected_shipping_rate.shipping_method).to eq(shipping_method_2)
        end
      end

      context 'update all shipments' do
        it { expect(execute.success?).to eq(true) }

        it 'sets selected shipping method for all shipments' do
          expect(order.shipments.count).to eq(2)
          expect(shipment.selected_shipping_rate.shipping_method).to eq(shipping_method)
          expect(shipment_2.selected_shipping_rate.shipping_method).to eq(shipping_method)
          execute
          expect(shipment.reload.selected_shipping_rate.shipping_method).to eq(shipping_method_2)
          expect(shipment_2.reload.selected_shipping_rate.shipping_method).to eq(shipping_method_2)
        end
      end
    end
  end
end
