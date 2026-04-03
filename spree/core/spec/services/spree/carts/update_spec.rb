require 'spec_helper'

module Spree
  RSpec.describe Carts::Update do
    let(:store) { create(:store, supported_currencies: 'USD,EUR,GBP') }
    let(:user) { create(:user) }
    let(:order) { create(:order_with_line_items, user: user, store: store, currency: 'USD') }

    describe '#call' do
      subject { described_class.call(cart: order, params: params) }

      describe 'updating email' do
        let(:params) { { email: 'new@example.com' } }

        it 'updates the order email' do
          expect(subject).to be_success
          expect(order.reload.email).to eq('new@example.com')
        end
      end

      describe 'updating customer_note' do
        let(:params) { { customer_note: 'Leave at the door' } }

        it 'updates the customer note' do
          expect(subject).to be_success
          expect(order.reload.special_instructions).to eq('Leave at the door')
        end

        context 'when clearing customer_note' do
          let(:order) { create(:order_with_line_items, user: user, store: store, special_instructions: 'Existing instructions') }

          it 'clears with empty string' do
            result = described_class.call(cart: order, params: { customer_note: '' })
            expect(result).to be_success
            expect(order.reload.special_instructions).to eq('')
          end

          it 'clears with nil' do
            result = described_class.call(cart: order, params: { customer_note: nil })
            expect(result).to be_success
            expect(order.reload.special_instructions).to be_nil
          end
        end
      end

      describe 'updating currency' do
        context 'with supported currency' do
          let(:params) { { currency: 'EUR' } }

          it 'updates the currency' do
            expect(subject).to be_success
            expect(order.reload.currency).to eq('EUR')
          end

          it 'is case-insensitive' do
            result = described_class.call(cart: order, params: { currency: 'eur' })
            expect(result).to be_success
            expect(order.reload.currency).to eq('EUR')
          end
        end

        context 'with unsupported currency' do
          let(:params) { { currency: 'JPY' } }

          it 'returns failure' do
            expect(subject).to be_failure
          end

          it 'does not change the currency' do
            subject
            expect(order.reload.currency).to eq('USD')
          end
        end

        context 'auto-switches market to match currency' do
          let(:us_country) { Spree::Country.find_by(iso: 'US') || create(:country, iso: 'US') }
          let(:de_country) { create(:country, iso: 'DE', name: 'Germany') }
          let!(:us_market) { create(:market, store: store, countries: [us_country]) }
          let!(:eu_market) { create(:market, :eu, store: store, countries: [de_country]) }
          let(:order) { create(:order_with_line_items, user: user, store: store, market: us_market, currency: 'USD') }

          it 'switches market when currency changes' do
            result = described_class.call(cart: order, params: { currency: 'EUR' })

            expect(result).to be_success
            expect(order.reload.currency).to eq('EUR')
            expect(order.market).to eq(eu_market)
          end

          it 'does not switch market when currency matches current market' do
            result = described_class.call(cart: order, params: { currency: 'USD' })

            expect(result).to be_success
            expect(order.reload.market).to eq(us_market)
          end

          it 'does not switch market when market_id is explicitly provided' do
            result = described_class.call(cart: order, params: { currency: 'EUR', market_id: us_market.prefixed_id })

            expect(result).to be_success
            expect(order.reload.market).to eq(us_market)
          end

          it 'returns failure when no market exists for currency' do
            result = described_class.call(cart: order, params: { currency: 'GBP' })

            expect(result).to be_failure
            expect(order.reload.currency).to eq('USD')
            expect(order.market).to eq(us_market)
          end
        end
      end

      describe 'updating market' do
        let(:us_country) { Spree::Country.find_by(iso: 'US') || create(:country, iso: 'US') }
        let(:de_country) { create(:country, iso: 'DE', name: 'Germany') }
        let!(:us_market) { create(:market, store: store, countries: [us_country]) }
        let!(:eu_market) { create(:market, :eu, store: store, countries: [de_country]) }

        context 'with valid market_id' do
          let(:params) { { market_id: eu_market.prefixed_id } }

          it 'updates the market' do
            expect(subject).to be_success
            expect(order.reload.market).to eq(eu_market)
          end
        end

        context 'with invalid market_id' do
          let(:params) { { market_id: 'mkt_invalid' } }

          it 'raises RecordNotFound' do
            expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end

        context 'when shipping address country is not in the new market' do
          let!(:us_state) { us_country.states.find_by(abbr: 'NY') || create(:state, country: us_country, abbr: 'NY', name: 'New York') }
          let(:us_address) { create(:address, country: us_country, state: us_state) }
          let(:order) { create(:order_with_line_items, user: user, store: store, market: us_market, ship_address: us_address, state: 'delivery') }
          let(:params) { { market_id: eu_market.prefixed_id } }

          it 'clears the shipping address' do
            expect(order.ship_address).to be_present
            expect(subject).to be_success
            expect(order.reload.ship_address).to be_nil
          end

          it 'reverts checkout state to address' do
            expect(subject).to be_success
            # After revert + try_advance, state depends on checkout flow
            # but it should not remain past address without a valid shipping address
            expect(order.reload.state).to eq('address')
          end
        end

        context 'when shipping address country is in the new market' do
          let(:de_address) { create(:address, country: de_country) }
          let(:order) { create(:order_with_line_items, user: user, store: store, market: us_market, ship_address: de_address) }
          let(:params) { { market_id: eu_market.prefixed_id } }

          it 'keeps the shipping address' do
            expect(subject).to be_success
            expect(order.reload.ship_address).to eq(de_address)
          end
        end
      end

      describe 'updating addresses' do
        let(:country) { Spree::Country.find_by(iso: 'US') || create(:country, iso: 'US') }
        let!(:state) { country.states.find_by(abbr: 'NY') || create(:state, country: country, abbr: 'NY', name: 'New York') }

        shared_examples 'address update' do |address_type|
          let(:address_key) { address_type }
          let(:address_id_key) { :"#{address_type}_id" }

          context 'with new address attributes' do
            let(:params) do
              {
                address_key => {
                  first_name: 'John',
                  last_name: 'Doe',
                  address1: '123 Main St',
                  city: 'New York',
                  postal_code: '10001',
                  country_iso: 'US',
                  state_abbr: 'NY',
                  phone: '555-1234'
                }
              }
            end

            it 'creates a new address' do
              expect(subject).to be_success
              address = order.reload.public_send(address_key)
              expect(address.first_name).to eq('John')
              expect(address.last_name).to eq('Doe')
              expect(address.address1).to eq('123 Main St')
              expect(address.city).to eq('New York')
              expect(address.postal_code).to eq('10001')
              expect(address.country.iso).to eq('US')
              expect(address.state.abbr).to eq('NY')
            end

            context 'when order has address checkout step and is past address state' do
              let(:order) { create(:order_with_line_items, user: user, store: store, state: 'delivery') }

              it 'reverts to address then auto-advances to payment' do
                expect(subject).to be_success
                expect(order.reload.state).to eq('payment')
              end
            end

            context 'when order is in cart state' do
              let(:order) { create(:order_with_line_items, user: user, store: store, state: 'cart') }

              it 'auto-advances to payment' do
                expect(subject).to be_success
                expect(order.reload.state).to eq('payment')
              end
            end

            context 'when order is fully covered by store credit payment' do
              let(:order) { create(:order_with_line_items, user: user, store: store, state: 'cart') }

              before do
                create(:store_credit_payment, order: order, amount: order.total)
              end

              it 'does not auto-complete the order' do
                expect(subject).to be_success
                expect(order.reload.state).not_to eq('complete')
              end

              it 'stops at the last step before complete' do
                expect(subject).to be_success
                steps = order.checkout_steps
                final_step = steps[steps.index('complete') - 1]
                expect(order.reload.state).to eq(final_step)
              end
            end
          end

          context 'with existing address by nested id' do
            let(:existing_address) { create(:address, user: user) }
            let(:params) { { address_key => { id: existing_address.prefixed_id } } }

            it 'uses the existing address' do
              expect(subject).to be_success
              expect(order.reload.public_send(address_id_key)).to eq(existing_address.id)
            end
          end

          context 'with top-level address_id parameter' do
            let(:existing_address) { create(:address, user: user) }
            let(:params) { { address_id_key => existing_address.prefixed_id } }

            it 'uses the existing address' do
              expect(subject).to be_success
              expect(order.reload.public_send(address_id_key)).to eq(existing_address.id)
            end
          end
        end

        describe 'shipping_address' do
          include_examples 'address update', :shipping_address
        end

        describe 'billing_address' do
          include_examples 'address update', :billing_address
        end
      end

      describe 'billing address does not reset checkout state' do
        let(:country) { Spree::Country.find_by(iso: 'US') || create(:country, iso: 'US') }
        let!(:state) { country.states.find_by(abbr: 'NY') || create(:state, country: country, abbr: 'NY', name: 'New York') }
        let(:order) { create(:order_with_line_items, user: user, store: store, state: 'delivery') }

        let(:params) do
          {
            billing_address: {
              first_name: 'Jane',
              last_name: 'Doe',
              address1: '456 Oak Ave',
              city: 'New York',
              postal_code: '10002',
              country_iso: 'US',
              state_abbr: 'NY',
              phone: '555-9999'
            }
          }
        end

        it 'does not revert order state to address' do
          # Capture shipments before the update
          order.reload
          shipment_ids = order.shipments.pluck(:id)
          expect(shipment_ids).not_to be_empty

          expect(subject).to be_success

          order.reload
          # Shipments should be preserved (not recreated)
          expect(order.shipments.pluck(:id)).to eq(shipment_ids)
        end
      end

      describe 'use_shipping (billing same as shipping)' do
        let(:country) { Spree::Country.find_by(iso: 'US') || create(:country, iso: 'US') }
        let!(:state) { country.states.find_by(abbr: 'NY') || create(:state, country: country, abbr: 'NY', name: 'New York') }

        let(:shipping_address) do
          {
            first_name: 'John',
            last_name: 'Doe',
            address1: '123 Main St',
            city: 'New York',
            postal_code: '10001',
            country_iso: 'US',
            state_abbr: 'NY',
            phone: '555-1234'
          }
        end

        it 'copies shipping address to billing address' do
          # First set a shipping address
          result = described_class.call(cart: order, params: { shipping_address: shipping_address })
          expect(result).to be_success

          # Then use_shipping to copy it to billing
          result = described_class.call(cart: order, params: { use_shipping: true })
          expect(result).to be_success

          order.reload
          expect(order.bill_address).to be_present
          expect(order.bill_address.first_name).to eq('John')
          expect(order.bill_address.address1).to eq('123 Main St')
          expect(order.bill_address.postal_code).to eq('10001')
        end

        it 'works when set alongside shipping address in the same request' do
          params = { shipping_address: shipping_address, use_shipping: true }
          result = described_class.call(cart: order, params: params)
          expect(result).to be_success

          order.reload
          expect(order.ship_address.first_name).to eq('John')
          expect(order.bill_address.first_name).to eq('John')
          expect(order.bill_address.address1).to eq(order.ship_address.address1)
        end

        it 'does not copy when use_shipping is false' do
          # Set shipping address first
          described_class.call(cart: order, params: { shipping_address: shipping_address })
          original_bill_address_id = order.reload.bill_address_id

          result = described_class.call(cart: order, params: { use_shipping: false })
          expect(result).to be_success
          expect(order.reload.bill_address_id).to eq(original_bill_address_id)
        end
      end

      describe 'address ownership' do
        let(:other_user) { create(:user) }
        let(:other_users_address) { create(:address, user: other_user) }

        shared_examples 'ignores other users address' do |address_type|
          context "when using another user's address for #{address_type}" do
            let(:params) { { address_type => { id: other_users_address.prefixed_id } } }

            it 'ignores the address and keeps original' do
              original_address_id = order.public_send(:"#{address_type}_id")
              expect(subject).to be_success
              expect(order.reload.public_send(:"#{address_type}_id")).to eq(original_address_id)
              expect(order.public_send(:"#{address_type}_id")).not_to eq(other_users_address.id)
            end
          end

          context "when using another user's address via #{address_type}_id" do
            let(:params) { { :"#{address_type}_id" => other_users_address.prefixed_id } }

            it 'ignores the address and keeps original' do
              original_address_id = order.public_send(:"#{address_type}_id")
              expect(subject).to be_success
              expect(order.reload.public_send(:"#{address_type}_id")).to eq(original_address_id)
              expect(order.public_send(:"#{address_type}_id")).not_to eq(other_users_address.id)
            end
          end
        end

        include_examples 'ignores other users address', :shipping_address
        include_examples 'ignores other users address', :billing_address

        context 'when order has no user (guest order)' do
          let(:order) { create(:order_with_line_items, user: nil, store: store) }
          let(:params) { { shipping_address_id: other_users_address.prefixed_id } }

          it 'ignores address_id params and keeps existing address' do
            original_address_id = order.ship_address_id
            expect(subject).to be_success
            expect(order.reload.ship_address_id).to eq(original_address_id)
          end
        end
      end

      describe 'updating metadata' do
        let(:params) { { metadata: { 'erp_id' => '12345', 'source' => 'mobile' } } }

        it 'merges metadata into the order' do
          expect(subject).to be_success
          expect(order.reload.metadata).to include('erp_id' => '12345', 'source' => 'mobile')
        end

        context 'with existing metadata' do
          before { order.update!(metadata: { 'existing_key' => 'existing_value' }) }

          let(:params) { { metadata: { 'new_key' => 'new_value' } } }

          it 'merges without removing existing keys' do
            expect(subject).to be_success
            expect(order.reload.metadata).to include('existing_key' => 'existing_value', 'new_key' => 'new_value')
          end
        end
      end

      describe 'updating multiple fields' do
        let(:country) { Spree::Country.find_by(iso: 'US') || create(:country, iso: 'US') }
        let!(:state) { country.states.find_by(abbr: 'NY') || create(:state, country: country, abbr: 'NY', name: 'New York') }

        let(:params) do
          {
            email: 'customer@example.com',
            customer_note: 'Handle with care',
            shipping_address: {
              first_name: 'John',
              last_name: 'Doe',
              address1: '123 Main St',
              city: 'New York',
              postal_code: '10001',
              country_iso: 'US',
              state_abbr: 'NY'
            }
          }
        end

        it 'updates all fields in a single transaction' do
          expect(subject).to be_success
          order.reload
          expect(order.email).to eq('customer@example.com')
          expect(order.customer_note).to eq('Handle with care')
          expect(order.shipping_address.first_name).to eq('John')
        end
      end

      describe 'setting line items' do
        let(:variant) { create(:variant) }

        before do
          variant.stock_items.first.update!(count_on_hand: 10)
          store.products << variant.product unless store.products.include?(variant.product)
        end

        context 'with new line_items' do
          let(:params) do
            {
              items: [
                { variant_id: variant.prefixed_id, quantity: 2 }
              ]
            }
          end

          it 'adds line items to the order' do
            expect(subject).to be_success
            order.reload
            line_item = order.line_items.find_by(variant: variant)
            expect(line_item).to be_present
            expect(line_item.quantity).to eq(2)
          end
        end

        context 'with existing line item (upsert)' do
          let!(:existing_line_item) { order.line_items.first }
          let(:existing_variant) { existing_line_item.variant }

          before do
            store.products << existing_variant.product unless store.products.include?(existing_variant.product)
          end

          let(:params) do
            {
              items: [
                { variant_id: existing_variant.prefixed_id, quantity: 7 }
              ]
            }
          end

          it 'sets quantity instead of incrementing' do
            expect(subject).to be_success
            expect(existing_line_item.reload.quantity).to eq(7)
          end
        end

        context 'with invalid variant_id' do
          let(:params) do
            {
              items: [
                { variant_id: 'variant_invalid999', quantity: 1 }
              ]
            }
          end

          it 'raises RecordNotFound with variant details' do
            expect { subject }.to raise_error(ActiveRecord::RecordNotFound) do |error|
              expect(error.model).to eq('Spree::Variant')
              expect(error.message).to include('variant_invalid999')
            end
          end
        end
      end

      describe 'error handling' do
        context 'with invalid address prefix_id' do
          let(:params) { { shipping_address_id: 'addr_invalid123' } }

          it 'succeeds but does not change the address' do
            original_address_id = order.ship_address_id
            expect(subject).to be_success
            expect(order.reload.ship_address_id).to eq(original_address_id)
          end
        end

        context 'when order save fails' do
          let(:params) { { email: 'new@example.com' } }

          before do
            allow(order).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(order))
          end

          it 'returns failure with error message' do
            expect(subject).to be_failure
          end
        end
      end

      describe 'parameter normalization' do
        let(:params) { { 'email' => 'string_key@example.com' } }

        it 'handles string keys' do
          expect(subject).to be_success
          expect(order.reload.email).to eq('string_key@example.com')
        end
      end

    end
  end
end
