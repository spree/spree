require 'spec_helper'

module Spree
  RSpec.describe Orders::Update do
    let(:store) { @default_store }
    let(:user) { create(:user) }
    let(:product) { create(:product_in_stock, stores: [store]) }
    let(:variant) { product.default_variant }

    # Real shipping setup so Stock::Coordinator can produce shipments
    # for the rebuild flows.
    let(:country) { @default_country }
    let(:state)   { country.states.first || create(:state, country: country) }
    let(:other_country) { create(:country) }
    let(:other_state)   { create(:state, country: other_country) }
    let!(:zone)   { create(:zone) }
    let!(:zone_member) { create(:zone_member, zone: zone, zoneable: country) }
    let!(:other_zone)  { create(:zone) }
    let!(:other_zone_member) { create(:zone_member, zone: other_zone, zoneable: other_country) }
    let!(:shipping_method) do
      create(:shipping_method, zones: [zone, other_zone]).tap do |sm|
        sm.calculator.preferred_amount = 5
        sm.calculator.save
      end
    end
    let!(:stock_location) { Spree::StockLocation.first || create(:stock_location, country: country, state: state) }

    let(:order) { create(:order, user: user, store: store) }

    describe '#call' do
      subject { described_class.call(order: order, params: params) }

      context 'with empty params' do
        let(:params) { {} }

        it 'returns success' do
          expect(subject).to be_success
        end
      end

      context 'updating scalar attributes' do
        let(:params) { { email: 'new@example.com', customer_note: 'Leave at door' } }

        it 'updates the order' do
          expect(subject).to be_success
          order.reload
          expect(order.email).to eq('new@example.com')
          expect(order.customer_note).to eq('Leave at door')
        end
      end

      context 'with items array' do
        let(:params) do
          { items: [{ variant_id: variant.prefixed_id, quantity: 2 }] }
        end

        it 'creates the line item' do
          expect(subject).to be_success
          order.reload
          expect(order.line_items.find_by(variant: variant).quantity).to eq(2)
        end
      end

      context 'with both attributes and items' do
        let(:params) do
          {
            email: 'order@example.com',
            items: [{ variant_id: variant.prefixed_id, quantity: 1 }]
          }
        end

        it 'updates both' do
          expect(subject).to be_success
          order.reload
          expect(order.email).to eq('order@example.com')
          expect(order.line_items.find_by(variant: variant)).to be_present
        end
      end

      context 'with item that fails (currency mismatch)' do
        let(:order) { create(:order, user: user, store: store, currency: 'GBP') }
        let(:params) do
          {
            email: 'gbp@example.com',
            items: [{ variant_id: variant.prefixed_id, quantity: 1 }]
          }
        end

        it 'rolls back the entire update' do
          expect(subject).to be_failure
          expect(order.reload.email).not_to eq('gbp@example.com')
          expect(order.line_items.count).to eq(0)
        end
      end

      context 'with invalid variant in items' do
        let(:params) do
          {
            email: 'before@example.com',
            items: [{ variant_id: 'variant_doesnotexist', quantity: 1 }]
          }
        end

        it 'raises RecordNotFound and does not commit attribute changes' do
          expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
          expect(order.reload.email).not_to eq('before@example.com')
        end
      end

      context 'with empty items array' do
        let(:params) { { items: [] } }

        it 'is a no-op for items, returns success' do
          expect(subject).to be_success
          expect(order.line_items.count).to eq(0)
        end
      end

      context 'replaces an existing line item quantity' do
        let!(:existing) { create(:line_item, order: order, variant: variant, quantity: 5) }
        let(:params) do
          { items: [{ variant_id: variant.prefixed_id, quantity: 2 }] }
        end

        it 'sets quantity to 2 (not 7)' do
          expect(subject).to be_success
          expect(existing.reload.quantity).to eq(2)
        end
      end

      context 'with string keys' do
        let(:params) do
          { 'email' => 'string@example.com', 'items' => [{ 'variant_id' => variant.prefixed_id, 'quantity' => 1 }] }
        end

        it 'handles string keys' do
          expect(subject).to be_success
          order.reload
          expect(order.email).to eq('string@example.com')
          expect(order.line_items.find_by(variant: variant)).to be_present
        end
      end

      describe 'shipment rebuild' do
        # Order seeded with a shipping address + line item + an initial shipment.
        let(:initial_address) { create(:address, country: country, state: state) }
        let(:order) do
          o = create(:order, user: user, store: store, ship_address: initial_address)
          described_class.call(order: o, params: { items: [{ variant_id: variant.prefixed_id, quantity: 1 }] })
          o.reload
        end

        it 'starts with shipments built from the seeded data' do
          expect(order.shipments).not_to be_empty
          expect(order.shipment_total).to eq(5)
        end

        context 'when items change' do
          let(:params) { { items: [{ variant_id: variant.prefixed_id, quantity: 3 }] } }

          it 'rebuilds shipments to reflect the new line item state' do
            old_shipment_ids = order.shipments.map(&:id)

            expect(subject).to be_success

            order.reload
            new_shipment_ids = order.shipments.map(&:id)

            expect(order.line_items.find_by(variant: variant).quantity).to eq(3)
            expect(new_shipment_ids).not_to be_empty
            expect(new_shipment_ids & old_shipment_ids).to be_empty
            expect(order.shipments.first.inventory_units.sum(:quantity)).to eq(3)
            expect(order.shipment_total).to eq(5)
          end
        end

        context 'when shipping address changes' do
          let(:new_address_attrs) do
            {
              firstname: 'Bob', lastname: 'Stone',
              address1: '99 New Street', city: 'Other City',
              zipcode: '99999', phone: '555-000-9999',
              country_id: other_country.id, state_id: other_state.id
            }
          end
          let(:params) { { ship_address_attributes: new_address_attrs } }

          it 'rebuilds shipments against the new address' do
            old_shipment_ids = order.shipments.map(&:id)

            expect(subject).to be_success

            order.reload
            expect(order.ship_address.country_id).to eq(other_country.id)
            expect(order.ship_address.address1).to eq('99 New Street')

            new_shipment_ids = order.shipments.map(&:id)
            expect(new_shipment_ids).not_to be_empty
            expect(new_shipment_ids & old_shipment_ids).to be_empty
          end
        end

        context 'when neither items nor shipping address change' do
          let(:params) { { customer_note: 'whatever' } }

          it 'does not rebuild shipments — same shipment IDs stay in place' do
            old_shipment_ids = order.shipments.map(&:id)

            expect(subject).to be_success

            order.reload
            expect(order.shipments.map(&:id)).to match_array(old_shipment_ids)
            expect(order.customer_note).to eq('whatever')
          end
        end
      end

      describe 'final totals refresh' do
        it 'persists totals after the pipeline runs' do
          described_class.call(order: order, params: { items: [{ variant_id: variant.prefixed_id, quantity: 2 }] })

          order.reload
          expect(order.line_items.first.quantity).to eq(2)
          expect(order.item_total).to eq(variant.price * 2)
          expect(order.total).to eq(order.item_total + order.shipment_total + order.adjustment_total)
        end
      end

      describe 'with an automatic free-shipping promotion' do
        let!(:promotion) { create(:free_shipping_promotion, kind: :automatic, stores: [store]) }
        let(:initial_address) { create(:address, country: country, state: state) }
        let(:order) { create(:order, user: user, store: store, ship_address: initial_address) }

        it 'applies the promo when items are added so delivery cost nets to zero' do
          described_class.call(order: order, params: { items: [{ variant_id: variant.prefixed_id, quantity: 1 }] })

          order.reload
          shipment = order.shipments.first
          expect(shipment).to be_present
          expect(shipment.adjustment_total).to eq(-5)
          expect(order.shipping_discount).to eq(5)
          expect(order.total).to eq(order.item_total)
        end

        it 're-applies the promo when shipping address changes' do
          # Seed: order with line item + shipments + promo applied
          described_class.call(order: order, params: { items: [{ variant_id: variant.prefixed_id, quantity: 1 }] })
          order.reload
          expect(order.shipping_discount).to eq(5)

          # Move to a different country — shipments rebuild, promo must re-apply
          described_class.call(order: order, params: {
            ship_address_attributes: {
              firstname: 'Bob', lastname: 'Stone',
              address1: '99 New Street', city: 'Other City',
              zipcode: '99999', phone: '555-000-9999',
              country_id: other_country.id, state_id: other_state.id
            }
          })

          order.reload
          expect(order.shipments.first.adjustment_total).to eq(-5)
          expect(order.shipping_discount).to eq(5)
          expect(order.total).to eq(order.item_total)
        end
      end
    end
  end
end
