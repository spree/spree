require 'spec_helper'

module Spree
  RSpec.describe Orders::Create do
    let(:store) { @default_store }
    let(:user) { create(:user) }

    # Real shipping setup so Stock::Coordinator actually produces shipments.
    let(:country) { @default_country }
    let(:state)   { country.states.first || create(:state, country: country) }
    let!(:zone)   { create(:zone) }
    let!(:zone_member) { create(:zone_member, zone: zone, zoneable: country) }
    let!(:shipping_method) do
      create(:shipping_method, zones: [zone]).tap do |sm|
        sm.calculator.preferred_amount = 5
        sm.calculator.save
      end
    end
    let!(:stock_location) { Spree::StockLocation.first || create(:stock_location, country: country, state: state) }

    let(:product) { create(:product_in_stock, stores: [store]) }
    let(:variant) { product.default_variant }

    let(:address_attrs) do
      {
        firstname: 'Jane', lastname: 'Doe',
        address1: '350 Fifth Avenue', city: 'New York',
        zipcode: '10118', phone: '555-555-0199',
        country_id: country.id, state_id: state.id
      }
    end

    describe '#call' do
      subject { described_class.call(store: store, user: user, params: params) }

      context 'without a store' do
        it 'fails' do
          result = described_class.call(store: nil)
          expect(result).to be_failure
          expect(result.value).to eq(:store_is_required)
        end
      end

      context 'with minimal params (no items, no address)' do
        let(:params) { { email: 'new@example.com' } }

        it 'creates a draft order with no shipments' do
          expect(subject).to be_success
          order = subject.value
          expect(order).to be_persisted
          expect(order.status).to eq('draft')
          expect(order.shipments).to be_empty
          expect(order.shipment_total).to eq(0)
        end
      end

      context 'with items but no shipping address' do
        let(:params) do
          {
            email: 'new@example.com',
            items: [{ variant_id: variant.prefixed_id, quantity: 2 }]
          }
        end

        it 'does not build shipments — total reflects only items' do
          expect(subject).to be_success
          order = subject.value
          expect(order.line_items.count).to eq(1)
          expect(order.shipments).to be_empty
          expect(order.shipment_total).to eq(0)
          expect(order.total).to eq(order.item_total)
        end
      end

      context 'with shipping address but no items' do
        let(:params) do
          {
            email: 'new@example.com',
            shipping_address: address_attrs
          }
        end

        it 'does not build shipments' do
          expect(subject).to be_success
          order = subject.value
          expect(order.ship_address).to be_present
          expect(order.shipments).to be_empty
          expect(order.shipment_total).to eq(0)
        end
      end

      context 'happy path: items + shipping address' do
        let(:params) do
          {
            email: 'new@example.com',
            items: [{ variant_id: variant.prefixed_id, quantity: 2 }],
            shipping_address: address_attrs
          }
        end

        it 'creates shipments and rolls delivery cost into the order total' do
          expect(subject).to be_success
          order = subject.value

          expect(order.line_items.count).to eq(1)
          expect(order.shipments).not_to be_empty
          expect(order.shipments.first.shipping_rates).not_to be_empty
          expect(order.shipments.first.selected_shipping_rate).to be_present

          expect(order.shipment_total).to eq(5)
          expect(order.total).to eq(order.item_total + order.shipment_total + order.adjustment_total)
        end

        it 'persists the totals to the database' do
          subject
          order = subject.value.reload
          expect(order.shipment_total).to eq(5)
          expect(order.total).to eq(order.item_total + 5 + order.adjustment_total)
        end
      end

      context 'when delivery is not required' do
        let(:params) do
          {
            email: 'new@example.com',
            items: [{ variant_id: variant.prefixed_id, quantity: 1 }],
            shipping_address: address_attrs
          }
        end

        before do
          allow_any_instance_of(Spree::Order).to receive(:delivery_required?).and_return(false)
        end

        it 'does not build shipments' do
          expect(subject).to be_success
          expect(subject.value.shipments).to be_empty
          expect(subject.value.shipment_total).to eq(0)
        end
      end

      context 'with a free-shipping coupon code' do
        let!(:promotion) do
          create(:free_shipping_promotion, code: 'SHIP10', stores: [store])
        end

        let(:params) do
          {
            email: 'new@example.com',
            items: [{ variant_id: variant.prefixed_id, quantity: 1 }],
            shipping_address: address_attrs,
            coupon_code: 'SHIP10'
          }
        end

        it 'builds shipments first, then the free-shipping promo cancels the delivery cost' do
          expect(subject).to be_success
          order = subject.value

          # Shipments still exist, gross cost is still 5 (cost column on the shipment)
          expect(order.shipments.size).to eq(1)
          expect(order.shipment_total).to eq(5)

          # Promo created a -5 adjustment on the shipment
          shipment = order.shipments.first
          expect(shipment.adjustment_total).to eq(-5)
          expect(shipment.adjustments.promotion.size).to eq(1)
          expect(order.shipping_discount).to eq(5)

          # Promotion is associated with the order
          expect(order.promotions).to include(promotion)

          # Customer-visible total is item_total only — free shipping nets out
          expect(order.total).to eq(order.item_total)
        end
      end

      context 'with an automatic free-shipping promotion (no coupon code)' do
        let!(:promotion) do
          create(:free_shipping_promotion, kind: :automatic, stores: [store])
        end

        let(:params) do
          {
            email: 'new@example.com',
            items: [{ variant_id: variant.prefixed_id, quantity: 1 }],
            shipping_address: address_attrs
          }
        end

        it 'applies the promotion during shipment building, even without a coupon code' do
          expect(subject).to be_success
          order = subject.value

          shipment = order.shipments.first
          expect(shipment).to be_present
          expect(shipment.adjustment_total).to eq(-5)
          expect(order.shipping_discount).to eq(5)
          expect(order.total).to eq(order.item_total)
        end
      end
    end
  end
end
