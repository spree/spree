require 'spec_helper'

module Spree
  module Core
    describe Importer::Order do
      let!(:country) { create(:country, iso: 'US', iso3: 'USA') }
      let!(:state) { country.states.first || create(:state, country: country) }
      let!(:stock_location) { create(:stock_location, admin_name: 'Admin Name') }

      let(:user) { stub_model(LegacyUser, email: 'fox@mudler.com') }
      let(:shipping_method) { create(:shipping_method) }
      let(:payment_method) { create(:check_payment_method) }

      let(:product) do
        product = Spree::Product.create(name: 'Test',
                                        sku: 'TEST-1',
                                        price: 33.22, available_on: Time.current - 1.day)
        product.shipping_category = create(:shipping_category)
        product.save
        product
      end

      let(:variant) do
        variant = product.master
        variant.stock_items.each { |si| si.update_attribute(:count_on_hand, 10) }
        variant
      end

      let(:sku) { variant.sku }
      let(:variant_id) { variant.id }

      let(:line_items) { [{ variant_id: variant.id, quantity: 5 }] }
      let(:ship_address) do
        {
          address1: '123 Testable Way',
          firstname: 'Fox',
          lastname: 'Mulder',
          city: 'Washington',
          country_id: country.id,
          state_id: state.id,
          zipcode: '66666',
          phone: '666-666-6666'
        }
      end

      it 'can import an order number' do
        params = { number: '123-456-789' }
        order = Importer::Order.import(user, params)
        expect(order.number).to eq '123-456-789'
      end

      it 'optionally add completed at' do
        params = {
          email: 'test@test.com',
          completed_at: Time.current,
          line_items_attributes: line_items
        }

        order = Importer::Order.import(user, params)
        expect(order).to be_completed
        expect(order.state).to eq 'complete'
      end

      it 'assigns order[email] over user email to order' do
        params = { email: 'wooowww@test.com' }
        order = Importer::Order.import(user, params)
        expect(order.email).to eq params[:email]
      end

      context 'assigning a user to an order' do
        let(:other_user) { stub_model(LegacyUser, email: 'dana@scully.com') }

        context 'as an admin' do
          before { allow(user).to receive_messages has_spree_role?: true }

          context "a user's id is not provided" do
            # this is a regression spec for an issue we ran into at Bonobos
            it "doesn't unassociate the admin from the order" do
              params = {}
              order = Importer::Order.import(user, params)
              expect(order.user_id).to eq(user.id)
            end
          end
        end

        context 'as a user' do
          before { allow(user).to receive_messages has_spree_role?: false }

          it 'does not assign the order to the other user' do
            params = { user_id: other_user.id }
            order = Importer::Order.import(user, params)
            expect(order.user_id).to eq(user.id)
          end
        end
      end

      it 'can build an order from API with just line items' do
        params = { line_items_attributes: line_items }

        expect(Importer::Order).to receive(:ensure_variant_id_from_params).and_return(variant_id: variant.id,
                                                                                      quantity: 5)
        order = Importer::Order.import(user, params)
        expect(order.user).to eq(nil)
        line_item = order.line_items.first
        expect(line_item.quantity).to eq(5)
        expect(line_item.variant_id).to eq(variant_id)
      end

      it 'handles line_item building exceptions' do
        line_items.first[:variant_id] = 'XXX'
        params = { line_items_attributes: line_items }

        expect { Importer::Order.import(user, params) }.to raise_error(/XXX/)
      end

      it 'handles line_item updating exceptions' do
        line_items.first[:currency] = 'GBP'
        params = { line_items_attributes: line_items }

        expect { Importer::Order.import(user, params) }.to raise_error(/Validation failed/)
      end

      it 'can build an order from API with variant sku' do
        params = { line_items_attributes: [{ sku: sku, quantity: 5 }] }

        order = Importer::Order.import(user, params)

        line_item = order.line_items.first
        expect(line_item.variant_id).to eq(variant_id)
        expect(line_item.quantity).to eq(5)
      end

      it 'handles exceptions when sku is not found' do
        params = { line_items_attributes: [{ sku: 'XXX', quantity: 5 }] }
        expect { Importer::Order.import(user, params) }.to raise_error(/XXX/)
      end

      it 'can build an order from API shipping address' do
        params = {
          ship_address_attributes: ship_address,
          line_items_attributes: line_items
        }

        order = Importer::Order.import(user, params)
        expect(order.ship_address.address1).to eq '123 Testable Way'
      end

      it 'can build an order from API with country attributes' do
        ship_address.delete(:country_id)
        ship_address[:country] = { 'iso' => 'US' }
        params = {
          ship_address_attributes: ship_address,
          line_items_attributes: line_items
        }

        order = Importer::Order.import(user, params)
        expect(order.ship_address.country.iso).to eq 'US'
      end

      it 'handles country lookup exceptions' do
        ship_address.delete(:country_id)
        ship_address[:country] = { 'iso' => 'XXX' }
        params = {
          ship_address_attributes: ship_address,
          line_items_attributes: line_items
        }

        expect { Importer::Order.import(user, params) }.to raise_error(/XXX/)
      end

      it 'can build an order from API with state attributes' do
        ship_address.delete(:state_id)
        ship_address[:state] = { 'name' => state.name }
        params = {
          ship_address_attributes: ship_address,
          line_items_attributes: line_items
        }

        order = Importer::Order.import(user, params)
        expect(order.ship_address.state.name).to eq state.name
      end

      context 'with a different currency' do
        before { variant.price_in('GBP').update_attribute(:price, 18.99) }

        it 'sets the order currency' do
          params = { currency: 'GBP' }
          order = Importer::Order.import(user, params)
          expect(order.currency).to eq 'GBP'
        end

        it 'can handle it when a line order price is specified' do
          params = {
            currency: 'GBP',
            line_items_attributes: line_items
          }
          line_items.first.merge! currency: 'GBP', price: 1.99
          order = Importer::Order.import(user, params)
          expect(order.currency).to eq 'GBP'
          expect(order.line_items.first.price).to eq 1.99
          expect(order.line_items.first.currency).to eq 'GBP'
        end
      end

      context 'state passed is not associated with country' do
        let(:params) do
          {
            ship_address_attributes: ship_address,
            line_items_attributes: line_items
          }
        end

        let(:other_state) { create(:state, name: 'Uhuhuh', country: create(:country)) }

        before do
          ship_address.delete(:state_id)
          ship_address[:state] = { 'name' => other_state.name }
        end

        it 'sets states name instead of state id' do
          order = Importer::Order.import(user, params)
          expect(order.ship_address.state_name).to eq other_state.name
        end
      end

      it 'sets state name if state record not found' do
        ship_address.delete(:state_id)
        ship_address[:state] = { 'name' => 'XXX' }
        params = {
          ship_address_attributes: ship_address,
          line_items_attributes: line_items
        }

        order = Importer::Order.import(user, params)
        expect(order.ship_address.state_name).to eq 'XXX'
      end

      context 'variant not deleted' do
        it 'ensures variant id from api' do
          hash = { sku: variant.sku }
          Importer::Order.ensure_variant_id_from_params(hash)
          expect(hash[:variant_id]).to eq variant.id
        end
      end

      context 'variant was deleted' do
        it 'raise error as variant shouldnt be found' do
          variant.product.destroy
          hash = { sku: variant.sku }
          expect { Importer::Order.ensure_variant_id_from_params(hash) }.to raise_error("Ensure order import variant: Variant w/SKU #{hash[:sku]} not found.")
        end
      end

      it 'ensures_country_id for country fields' do
        [:name, :iso, :iso_name, :iso3].each do |field|
          address = { country: { field => country.send(field) } }
          Importer::Order.ensure_country_id_from_params(address)
          expect(address[:country_id]).to eq country.id
        end
      end

      it 'raises with proper message when cant find country' do
        address = { country: { 'name' => 'NoNoCountry' } }
        expect { Importer::Order.ensure_country_id_from_params(address) }.to raise_error(/NoNoCountry/)
      end

      it 'ensures_state_id for state fields' do
        [:name, :abbr].each do |field|
          address = { country_id: country.id, state: { field => state.send(field) } }
          Importer::Order.ensure_state_id_from_params(address)
          expect(address[:state_id]).to eq state.id
        end
      end

      context 'shipments' do
        let(:params) do
          {
            line_items_attributes: line_items,
            shipments_attributes: [
              {
                tracking: '123456789',
                cost: '14.99',
                shipping_method: shipping_method.name,
                stock_location: stock_location.name,
                inventory_units: Array.new(3) { { sku: sku, variant_id: variant.id } }
              },
              {
                tracking: '123456789',
                cost: '14.99',
                shipping_method: shipping_method.name,
                stock_location: stock_location.name,
                inventory_units: Array.new(2) { { sku: sku, variant_id: variant.id } }
              }
            ]
          }
        end

        it 'ensures variant exists and is not deleted' do
          expect(Importer::Order).to receive(:ensure_variant_id_from_params).exactly(6).times { line_items.first }
          Importer::Order.import(user, params)
        end

        it 'builds them properly' do
          order = Importer::Order.import(user, params)
          shipment = order.shipments.first

          expect(shipment.cost.to_f).to eq 14.99
          expect(shipment.inventory_units.first.variant_id).to eq product.master.id
          expect(shipment.tracking).to eq '123456789'
          expect(shipment.shipping_rates.first.cost).to eq 14.99
          expect(shipment.selected_shipping_rate).to eq(shipment.shipping_rates.first)
          expect(shipment.stock_location).to eq stock_location
          expect(order.shipment_total.to_f).to eq 29.98
        end

        it 'allocates inventory units to the correct shipments' do
          order = Importer::Order.import(user, params)

          expect(order.inventory_units.count).to eq 2
          expect(order.shipments.first.inventory_units.count).to eq 1
          expect(order.shipments.first.inventory_units.first.quantity).to eq 3
          expect(order.shipments.last.inventory_units.count).to eq 1
          expect(order.shipments.last.inventory_units.first.quantity).to eq 2
        end

        it 'accepts admin name for stock location' do
          params[:shipments_attributes][0][:stock_location] = stock_location.admin_name
          order = Importer::Order.import(user, params)
          shipment = order.shipments.first

          expect(shipment.stock_location).to eq stock_location
        end

        it 'raises if cant find stock location' do
          params[:shipments_attributes][0][:stock_location] = 'doesnt exist'
          expect { Importer::Order.import(user, params) }.to raise_error(StandardError)
        end

        context 'when a shipping adjustment is present' do
          it 'creates the shipping adjustment' do
            adjustment_attributes = [{ label: 'Shipping Discount', amount: -5.00 }]
            params[:shipments_attributes][0][:adjustments_attributes] = adjustment_attributes
            order = Importer::Order.import(user, params)
            shipment = order.shipments.first

            expect(shipment.adjustments.first.label).to eq('Shipping Discount')
            expect(shipment.adjustments.first.amount).to eq(-5.00)
          end
        end

        context 'when completed_at and shipped_at present' do
          let(:params) do
            {
              completed_at: 2.days.ago,
              line_items_attributes: line_items,
              shipments_attributes: [
                {
                  tracking: '123456789',
                  cost: '4.99',
                  shipped_at: 1.day.ago,
                  shipping_method: shipping_method.name,
                  stock_location: stock_location.name,
                  inventory_units: [{ sku: sku }]
                }
              ]
            }
          end

          it 'builds them properly' do
            order = Importer::Order.import(user, params)
            shipment = order.shipments.first

            expect(shipment.cost.to_f).to eq 4.99
            expect(shipment.inventory_units.first.variant_id).to eq product.master.id
            expect(shipment.tracking).to eq '123456789'
            expect(shipment.shipped_at).to be_present
            expect(shipment.shipping_rates.first.cost).to eq 4.99
            expect(shipment.selected_shipping_rate).to eq(shipment.shipping_rates.first)
            expect(shipment.stock_location).to eq stock_location
            expect(shipment.state).to eq('shipped')
            expect(shipment.inventory_units.all?(&:shipped?)).to be true
            expect(order.shipment_state).to eq('shipped')
            expect(order.shipment_total.to_f).to eq 4.99
          end
        end
      end

      it 'handles shipment building exceptions' do
        params = {
          shipments_attributes: [
            {
              tracking: '123456789',
              cost: '4.99',
              shipping_method: 'XXX',
              inventory_units: [{ sku: sku }]
            }
          ]
        }
        expect { Importer::Order.import(user, params) }.to raise_error(/XXX/)
      end

      it 'adds adjustments' do
        params = {
          adjustments_attributes: [
            {
              label: 'Shipping Discount',
              amount: -4.99
            },
            {
              label: 'Promotion Discount',
              amount: -3.00
            }
          ]
        }

        order = Importer::Order.import(user, params)
        expect(order.adjustments.all?(&:closed?)).to be true
        expect(order.adjustments.first.label).to eq 'Shipping Discount'
        expect(order.adjustments.first.amount).to eq(-4.99)
      end

      it 'adds line item adjustments from promotion' do
        line_items.first[:adjustments_attributes] = [
          {
            label: 'Line Item Discount',
            amount: -4.99,
            promotion: true
          }
        ]
        params = {
          line_items_attributes: line_items,
          adjustments_attributes: [
            { label: 'Order Discount', amount: -5.99 }
          ]
        }

        order = Importer::Order.import(user, params)
        line_item_adjustment = order.line_item_adjustments.first
        expect(line_item_adjustment.closed?).to be true
        expect(line_item_adjustment.label).to eq 'Line Item Discount'
        expect(line_item_adjustment.amount).to eq(-4.99)
        expect(order.line_items.first.adjustment_total).to eq(-4.99)
      end

      it 'adds line item adjustments from taxation' do
        line_items.first[:adjustments_attributes] = [
          { label: 'Line Item Tax', amount: -4.99, tax: true }
        ]
        params = {
          line_items_attributes: line_items,
          adjustments_attributes: [
            { label: 'Order Discount', amount: -5.99 }
          ]
        }

        order = Importer::Order.import(user, params)

        line_item_adjustment = order.line_item_adjustments.first
        expect(line_item_adjustment.closed?).to be true
        expect(line_item_adjustment.label).to eq 'Line Item Tax'
        expect(line_item_adjustment.amount).to eq(-4.99)
        expect(order.line_items.first.adjustment_total).to eq(-4.99)
      end

      it 'calculates final order total correctly' do
        params = {
          adjustments_attributes: [
            { label: 'Promotion Discount', amount: -3.00 }
          ],
          line_items_attributes: [
            {
              variant_id: variant.id,
              quantity: 5
            }
          ]
        }

        order = Importer::Order.import(user, params)
        expect(order.item_total).to eq(166.1)
        expect(order.total).to eq(163.1) # = item_total (166.1) - adjustment_total (3.00)
      end

      it 'handles adjustment building exceptions' do
        params = {
          adjustments_attributes: [
            {
              amount: 'XXX'
            },
            {
              label: 'Promotion Discount',
              amount: '-3.00'
            }
          ]
        }

        expect { Importer::Order.import(user, params) }.to raise_error(/XXX/)
      end

      it 'builds a payment using state' do
        params = {
          payments_attributes: [
            {
              amount: '4.99',
              payment_method: payment_method.name,
              state: 'completed'
            }
          ]
        }
        order = Importer::Order.import(user, params)
        expect(order.payments.first.amount).to eq 4.99
      end

      it 'builds a payment using status as fallback' do
        params = {
          payments_attributes: [
            {
              amount: '4.99',
              payment_method: payment_method.name,
              status: 'completed'
            }
          ]
        }
        order = Importer::Order.import(user, params)
        expect(order.payments.first.amount).to eq 4.99
      end

      it 'handles payment building exceptions' do
        params = {
          payments_attributes: [
            {
              amount: '4.99',
              payment_method: 'XXX'
            }
          ]
        }
        expect { Importer::Order.import(user, params) }.to raise_error(/XXX/)
      end

      it 'build a source payment using years and month' do
        params = {
          payments_attributes: [
            {
              amount: '4.99',
              payment_method: payment_method.name,
              status: 'completed',
              source: {
                name: 'Fox',
                last_digits: '7424',
                cc_type: 'visa',
                year: '2022',
                month: '5'
              }
            }
          ]
        }

        order = Importer::Order.import(user, params)
        expect(order.payments.first.source.last_digits).to eq '7424'
      end

      it 'handles source building exceptions when do not have years and month' do
        params = {
          payments_attributes: [
            {
              amount: '4.99',
              payment_method: payment_method.name,
              status: 'completed',
              source: {
                name: 'Fox',
                last_digits: '7424',
                cc_type: 'visa'
              }
            }
          ]
        }

        expect { Importer::Order.import(user, params) }.
          to raise_error(/Validation failed: Credit card Month is not a number, Credit card Year is not a number/)
      end

      it 'builds a payment with an optional created_at' do
        created_at = 2.days.ago
        params = {
          payments_attributes: [
            {
              amount: '4.99',
              payment_method: payment_method.name,
              state: 'completed',
              created_at: created_at
            }
          ]
        }
        order = Importer::Order.import(user, params)
        expect(order.payments.first.created_at).to be_within(1).of created_at
      end

      context 'raises error' do
        it 'clears out order from db' do
          params = { payments_attributes: [{ payment_method: 'XXX' }] }
          count = Order.count

          expect { Importer::Order.import(user, params) }.to raise_error(StandardError)
          expect(Order.count).to eq count
        end
      end
    end
  end
end
