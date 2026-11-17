require 'spec_helper'

module Spree
  RSpec.describe Orders::Update do
    let(:store) { @default_store }
    let(:user) { create(:user) }
    let(:product) { create(:product_in_stock) }
    let(:variant) { product.default_variant }

    # Real shipping setup so Stock::Coordinator can produce shipments
    # for the rebuild flows.
    let(:country) { @default_country }
    let(:state)   { country.states.first || create(:state, country: country) }
    let(:other_country) { create(:country) }
    let(:other_state)   { create(:state, country: other_country) }
    let!(:zone)   { create(:zone) }
    let!(:other_zone)  { create(:zone) }
    let!(:shipping_method) do
      create(:delivery_method).tap do |sm|
        sm.calculator.preferred_amount = 5
        sm.calculator.save
      end
    end
    let!(:stock_location) { Spree::StockLocation.first || create(:stock_location, country: country, state: state) }

    let(:order) { create(:order, customer: user, store: store) }

    describe '#call' do
      subject { described_class.call(order: order, params: params) }

      context 'with a channel from another store' do
        let(:params) { { channel_id: create(:channel, store: create(:store)).prefixed_id } }

        it 'refuses it' do
          expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end

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
        let(:order) { create(:order, customer: user, store: store, currency: 'GBP') }
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

        it 'rolls back the entire update when the caller holds the order lock' do
          result = nil
          order.with_lock { result = described_class.call(order: order, params: params) }

          expect(result).to be_failure
          expect(order.reload.email).not_to eq('gbp@example.com')
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
          o = create(:order, customer: user, store: store, ship_address: initial_address)
          described_class.call(order: o, params: { items: [{ variant_id: variant.prefixed_id, quantity: 1 }] })
          o.reload
        end

        it 'starts with shipments built from the seeded data' do
          expect(order.shipments).not_to be_empty
          expect(order.delivery_total).to eq(5)
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
            expect(order.fulfillments.first.inventory_units.sum(:quantity)).to eq(3)
            expect(order.delivery_total).to eq(5)
          end
        end

        context 'when shipping address changes' do
          let(:new_address_attrs) do
            {
              firstname: 'Bob', lastname: 'Stone',
              address1: '99 New Street', city: 'Other City',
              zipcode: Spree::TestingSupport::CountryPool.postal_code_for(other_country.iso),
              phone: '555-000-9999',
              country_code: other_country.iso, state_abbr: other_state.abbr
            }
          end
          let(:params) { { shipping_address: new_address_attrs } }

          it 'rebuilds shipments against the new address' do
            old_shipment_ids = order.shipments.map(&:id)

            expect(subject).to be_success

            order.reload
            expect(order.ship_address.country_code).to eq(other_country.iso)
            expect(order.ship_address.address1).to eq('99 New Street')

            new_shipment_ids = order.shipments.map(&:id)
            expect(new_shipment_ids).not_to be_empty
            expect(new_shipment_ids & old_shipment_ids).to be_empty
          end
        end

        context 'when an admin chose a rate' do
          let(:initial_address) { create(:address, customer: user, country: country, state: state) }
          let!(:express) do
            create(:delivery_method, name: 'Express').tap do |method|
              method.calculator.preferred_amount = 15
              method.calculator.save
            end
          end

          before do
            fulfillment = order.fulfillments.first
            fulfillment.selected_delivery_rate_id = fulfillment.delivery_rates.find_by!(delivery_method: express).id
          end

          context 'and items change' do
            let(:params) { { items: [{ variant_id: variant.prefixed_id, quantity: 3 }] } }

            it 'keeps the chosen rate at its price' do
              expect(subject).to be_success

              expect(order.reload.fulfillments.first.selected_delivery_rate.delivery_method).to eq(express)
              expect(order.delivery_total).to eq(15)
            end
          end

          # An address edited in place keeps its id, yet it is a new destination.
          context 'and the shipping address is edited in place' do
            let(:params) { { shipping_address: { id: initial_address.id, address1: '5 Edited Way' } } }

            it 'rebuilds from the default rate' do
              expect(subject).to be_success

              order.reload
              expect(order.ship_address_id).to eq(initial_address.id)
              expect(order.ship_address.address1).to eq('5 Edited Way')
              expect(order.fulfillments.first.selected_delivery_rate.delivery_method).to eq(shipping_method)
              expect(order.delivery_total).to eq(5)
            end
          end

          context 'and only the recipient phone is edited' do
            let(:params) { { shipping_address: { id: initial_address.id, phone: '555-0000' } } }

            it 'keeps the chosen rate' do
              expect(subject).to be_success

              order.reload
              expect(order.ship_address.phone).to eq('555-0000')
              expect(order.fulfillments.first.selected_delivery_rate.delivery_method).to eq(express)
              expect(order.delivery_total).to eq(15)
            end
          end
        end

        # The admin controller sends the public names; the column names and the
        # Rails nested-attributes key stay accepted for existing callers.
        %i[shipping_address ship_address ship_address_attributes].each do |key|
          context "when the shipping address arrives as #{key}" do
            let(:params) { { key => attributes_for(:address).merge(address1: '1 Accepted Way') } }

            it 'applies the address' do
              expect(subject).to be_success
              expect(order.reload.ship_address.address1).to eq('1 Accepted Way')
            end
          end
        end

        # Every spelling is removed from the payload, so a client sending more
        # than one never leaves a key behind: a stray hash would reach the
        # belongs_to writer, and a stray `_attributes` key would quietly
        # overwrite the address applied here.
        context 'when the payload carries several spellings' do
          let(:params) do
            {
              shipping_address: attributes_for(:address).merge(address1: '1 Public Way'),
              ship_address: attributes_for(:address).merge(address1: '2 Column Way'),
              ship_address_attributes: attributes_for(:address).merge(address1: '3 Nested Way')
            }
          end

          it 'applies the public name and ignores the rest' do
            expect(subject).to be_success
            expect(order.reload.ship_address.address1).to eq('1 Public Way')
          end
        end

        context 'when only the column and nested spellings are sent' do
          let(:params) do
            {
              ship_address: attributes_for(:address).merge(address1: '2 Column Way'),
              ship_address_attributes: attributes_for(:address).merge(address1: '3 Nested Way')
            }
          end

          it 'prefers the column name' do
            expect(subject).to be_success
            expect(order.reload.ship_address.address1).to eq('2 Column Way')
          end
        end

        # The address rows are written before the order itself is saved, so a
        # failure afterwards has to take them with it.
        context 'when a scalar attribute is invalid alongside a valid address' do
          let(:params) do
            {
              shipping_address: attributes_for(:address).merge(address1: '9 Rolled Back Rd'),
              payment_status: 'not-a-real-status'
            }
          end

          it 'fails and leaves no address behind' do
            expect(subject).to be_failure
            expect(order.reload.ship_address.address1).not_to eq('9 Rolled Back Rd')
            expect(Spree::Address.where(address1: '9 Rolled Back Rd')).to be_empty
          end
        end

        # A rejected batch carries its reason on the Result, not on the order,
        # so raising RecordInvalid on the untouched order used to render a 422
        # with an empty message — the dashboard had nothing to display.
        context 'when the items batch is rejected' do
          let(:params) do
            { items: [{ variant_id: variant.prefixed_id, quantity: 1, price: '12,50' }] }
          end

          it 'fails with the reason on the order' do
            expect(subject).to be_failure
            expect(order.errors.full_messages.join).to include('non-negative number')
            expect(subject.error.to_s).to include('non-negative number')
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

        # A placed order's fulfillments carry the stock it promised, so an
        # edit adjusts them in place instead of replacing them.
        context 'when the order is placed and items change' do
          let(:params) { { items: [{ variant_id: variant.prefixed_id, quantity: 3 }] } }

          before { order.update_columns(status: 'placed', completed_at: Time.current) }

          it 'keeps the fulfillments and puts the new units on them' do
            old_shipment_ids = order.shipments.map(&:id)

            expect(subject).to be_success

            order.reload
            expect(order.shipments.map(&:id)).to match_array(old_shipment_ids)
            expect(order.fulfillments.first.fulfillment_items.sum(:quantity)).to eq(3)
          end

          it 'measures what has been paid against the new total' do
            create(:payment, amount: order.total, order: order, status: 'completed')
            order.update_statuses!

            expect { subject }.to change { order.reload.payment_status }.from('paid').to('partially_paid')
          end
        end
      end

      describe 'final totals refresh' do
        it 'persists totals after the pipeline runs' do
          described_class.call(order: order, params: { items: [{ variant_id: variant.prefixed_id, quantity: 2 }] })

          order.reload
          expect(order.line_items.first.quantity).to eq(2)
          expect(order.item_total).to eq(variant.amount_in(order.currency) * 2)
          expect(order.total).to eq(order.item_total + order.delivery_total + order.adjustment_total)
        end
      end

      describe 'with an automatic whole-order promotion for a customer group' do
        let(:customer_group) { create(:customer_group, store: store) }
        let(:member) { create(:user) }
        let!(:promotion) do
          create(:promotion, code: nil, kind: :automatic, store: store).tap do |promotion|
            Spree::Promotion::Rules::CustomerGroup.create!(promotion: promotion, preferred_customer_group_ids: [customer_group.id])
            calculator = Spree::Calculator::FlatPercentItemTotal.new(preferred_flat_percent: 10)
            Spree::Promotion::Actions::CreateAdjustment.create!(calculator: calculator, promotion: promotion)
          end
        end

        before { create(:customer_group_user, customer_group: customer_group, customer: member) }

        it 'applies it when items are added to an order for a customer in the group' do
          member_order = create(:order, customer: member, store: store)

          described_class.call(order: member_order, params: { items: [{ variant_id: variant.prefixed_id, quantity: 1 }] })

          member_order.reload
          expect(member_order.promotions).to include(promotion)
          expect(member_order.discount_total).to eq(-(member_order.item_total * 10 / 100).round(2))
        end

        it 'applies it when the order moves to a customer in the group, and drops the discount when it moves back' do
          described_class.call(order: order, params: { items: [{ variant_id: variant.prefixed_id, quantity: 1 }] })
          expect(order.reload.discount_total).to eq(0)

          described_class.call(order: order, params: { customer_id: member.id })
          expect(order.reload.promotions).to include(promotion)
          expect(order.discount_total).to eq(-(order.item_total * 10 / 100).round(2))

          described_class.call(order: order, params: { customer_id: user.id })
          expect(order.reload.discount_total).to eq(0)
        end
      end

      describe 'with an automatic promotion whose rule reads an attribute no core rule does' do
        # Named, so the rule row's STI type resolves.
        let(:metadata_rule_class) do
          stub_const('VipMetadataRule', Class.new(Spree::PromotionRule) do
            def applicable?(promotable)
              promotable.is_a?(Spree::Order)
            end

            def eligible?(order, _options = {})
              order.metadata.to_h['vip'] == '1'
            end
          end)
        end
        let!(:promotion) do
          create(:promotion, code: nil, kind: :automatic, store: store).tap do |promotion|
            metadata_rule_class.create!(promotion: promotion)
            calculator = Spree::Calculator::FlatPercentItemTotal.new(preferred_flat_percent: 10)
            Spree::Promotion::Actions::CreateAdjustment.create!(calculator: calculator, promotion: promotion)
          end
        end

        it 're-evaluates the promotion when that attribute changes' do
          described_class.call(order: order, params: { items: [{ variant_id: variant.prefixed_id, quantity: 1 }] })
          expect(order.reload.discount_total).to eq(0)

          described_class.call(order: order, params: { metadata: { vip: '1' } })
          expect(order.reload.promotions).to include(promotion)
          expect(order.discount_total).to eq(-(order.item_total * 10 / 100).round(2))

          described_class.call(order: order, params: { metadata: { vip: '0' } })
          expect(order.reload.discount_total).to eq(0)
        end
      end

      describe 'with an automatic promotion that gifts a physical item' do
        let(:gift) { create(:product_in_stock).default_variant }
        let(:initial_address) { create(:address, country: country, state: state) }
        let(:order) { create(:order, customer: user, store: store, ship_address: initial_address) }
        let!(:promotion) do
          create(:promotion, code: nil, kind: :automatic, store: store).tap do |promotion|
            create(:promotion_action_create_line_items, promotion: promotion).
              promotion_action_line_items.create!(variant: gift, quantity: 1)
          end
        end

        it 'puts the gifted line on a fulfillment' do
          described_class.call(order: order, params: { items: [{ variant_id: variant.prefixed_id, quantity: 1 }] })

          order.reload
          gift_line = order.line_items.find_by(variant_id: gift.id)
          expect(gift_line).to be_present
          expect(order.fulfillments.flat_map(&:inventory_units).map(&:line_item_id)).to include(gift_line.id)
        end

        context 'when only the customer changes and that makes the order qualify' do
          let(:customer_group) { create(:customer_group, store: store) }
          let(:member) { create(:user) }

          before do
            Spree::Promotion::Rules::CustomerGroup.create!(promotion: promotion, preferred_customer_group_ids: [customer_group.id])
            create(:customer_group_user, customer_group: customer_group, customer: member)
          end

          it 'puts the gifted line on a fulfillment, though the edit builds none of its own' do
            described_class.call(order: order, params: { items: [{ variant_id: variant.prefixed_id, quantity: 1 }] })
            expect(order.reload.line_items.find_by(variant_id: gift.id)).to be_nil

            described_class.call(order: order, params: { customer_id: member.id })

            order.reload
            gift_line = order.line_items.find_by(variant_id: gift.id)
            expect(gift_line).to be_present
            expect(order.fulfillments.flat_map(&:inventory_units).map(&:line_item_id)).to include(gift_line.id)
          end

          context 'and the order held only digital items until then' do
            let(:digital_variant) { create(:digital_product).default_variant }

            it 'builds a fulfillment for the gift and charges its delivery' do
              described_class.call(order: order, params: { items: [{ variant_id: digital_variant.prefixed_id, quantity: 1 }] })
              # A digital line sits on a fulfillment of its own, so the gift's
              # recalculation has one to rebuild.
              expect(order.reload.delivery_step_required?).to be(false)
              expect(order.fulfillments.flat_map(&:inventory_units).map(&:variant_id)).to eq([digital_variant.id])

              described_class.call(order: order, params: { customer_id: member.id })

              order.reload
              gift_line = order.line_items.find_by(variant_id: gift.id)
              expect(gift_line).to be_present
              expect(order.fulfillments.flat_map(&:inventory_units).map(&:line_item_id)).to include(gift_line.id)
              expect(order.delivery_total).to eq(5)
            end
          end

          it 'takes the gift off the fulfillments when the order stops qualifying' do
            described_class.call(order: order, params: { items: [{ variant_id: variant.prefixed_id, quantity: 1 }] })
            described_class.call(order: order, params: { customer_id: member.id })
            expect(order.reload.line_items.find_by(variant_id: gift.id)).to be_present

            described_class.call(order: order, params: { customer_id: user.id })

            order.reload
            expect(order.line_items.find_by(variant_id: gift.id)).to be_nil
            expect(order.fulfillments.flat_map(&:inventory_units).map(&:variant_id)).to contain_exactly(variant.id)
          end
        end
      end

      describe 'with an automatic free-shipping promotion' do
        let!(:promotion) { create(:free_shipping_promotion, kind: :automatic) }
        let(:initial_address) { create(:address, country: country, state: state) }
        let(:order) { create(:order, customer: user, store: store, ship_address: initial_address) }

        it 'applies the promo when items are added so delivery cost nets to zero' do
          described_class.call(order: order, params: { items: [{ variant_id: variant.prefixed_id, quantity: 1 }] })

          order.reload
          shipment = order.fulfillments.first
          expect(shipment).to be_present
          expect(shipment.adjustment_total).to eq(-5)
          expect(order.fulfillment_discount).to eq(5)
          expect(order.total).to eq(order.item_total)
        end

        it 're-applies the promo when shipping address changes' do
          # Seed: order with line item + shipments + promo applied
          described_class.call(order: order, params: { items: [{ variant_id: variant.prefixed_id, quantity: 1 }] })
          order.reload
          expect(order.fulfillment_discount).to eq(5)

          # Move to a different country — shipments rebuild, promo must re-apply
          described_class.call(order: order, params: {
            shipping_address: {
              firstname: 'Bob', lastname: 'Stone',
              address1: '99 New Street', city: 'Other City',
              zipcode: Spree::TestingSupport::CountryPool.postal_code_for(other_country.iso),
              phone: '555-000-9999',
              country_code: other_country.iso, state_abbr: other_state.abbr
            }
          })

          order.reload
          expect(order.fulfillments.first.adjustment_total).to eq(-5)
          expect(order.fulfillment_discount).to eq(5)
          expect(order.total).to eq(order.item_total)
        end
      end
    end
  end
end
