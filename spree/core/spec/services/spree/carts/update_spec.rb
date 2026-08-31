require 'spec_helper'

module Spree
  RSpec.describe Carts::Update do
    let(:store) { create(:store, supported_currencies: 'USD,EUR,GBP') }
    let!(:store_stock_location) { create(:stock_location, store: store, backorderable_default: true) }
    let!(:store_delivery_method) { create(:shipping_method, store: store) }
    let(:user) { create(:user) }
    let(:cart) { create(:cart_with_line_items, customer: user, store: store, currency: 'USD') }

    describe '#call' do
      subject { described_class.call(cart: cart, params: params) }

      describe 'updating email' do
        let(:params) { { email: 'new@example.com' } }

        it 'updates the cart email' do
          expect(subject).to be_success
          expect(cart.reload.email).to eq('new@example.com')
        end
      end

      describe 'updating customer_note' do
        let(:params) { { customer_note: 'Leave at the door' } }

        it 'updates the customer note' do
          expect(subject).to be_success
          expect(cart.reload.customer_note).to eq('Leave at the door')
        end

        context 'when clearing customer_note' do
          let(:cart) { create(:cart_with_line_items, customer: user, store: store, customer_note: 'Existing instructions') }

          it 'clears with empty string' do
            result = described_class.call(cart: cart, params: { customer_note: '' })
            expect(result).to be_success
            expect(cart.reload.customer_note).to eq('')
          end

          it 'clears with nil' do
            result = described_class.call(cart: cart, params: { customer_note: nil })
            expect(result).to be_success
            expect(cart.reload.customer_note).to be_nil
          end
        end
      end

      describe 'updating preferred_stock_location_id (pickup selection)' do
        let(:pickup_location) { create(:stock_location, pickup_enabled: true, store: store) }

        it 'resolves a prefixed id against the store pickup-enabled locations' do
          result = described_class.call(cart: cart, params: { preferred_stock_location_id: pickup_location.prefixed_id })

          expect(result).to be_success
          expect(cart.reload.preferred_stock_location_id).to eq(pickup_location.id)
          expect(cart.preferred_stock_location).to eq(pickup_location)
        end

        it 'accepts a raw id' do
          result = described_class.call(cart: cart, params: { preferred_stock_location_id: pickup_location.id })

          expect(result).to be_success
          expect(cart.reload.preferred_stock_location_id).to eq(pickup_location.id)
        end

        it 'clears the selection on blank' do
          cart.preferred_stock_location_id = pickup_location.id
          cart.save!

          result = described_class.call(cart: cart, params: { preferred_stock_location_id: '' })

          expect(result).to be_success
          expect(cart.reload.preferred_stock_location_id).to be_nil
        end

        it 'rejects a location that is not pickup-enabled' do
          not_pickup = create(:stock_location, pickup_enabled: false)

          expect {
            described_class.call(cart: cart, params: { preferred_stock_location_id: not_pickup.prefixed_id })
          }.to raise_error(ActiveRecord::RecordNotFound)
        end

        it 'rejects a pickup location belonging to another store' do
          other_store_location = create(:stock_location, pickup_enabled: true, store: create(:store))

          expect {
            described_class.call(cart: cart, params: { preferred_stock_location_id: other_store_location.prefixed_id })
          }.to raise_error(ActiveRecord::RecordNotFound)
        end

        it 'rebuilds delivery proposals when the pickup intent changes' do
          expect(cart).to receive(:recalculate_for_address_change!)

          described_class.call(cart: cart, params: { preferred_stock_location_id: pickup_location.prefixed_id })
        end

        it 'rebuilds delivery proposals when the pickup intent is cleared' do
          cart.update!(preferred_stock_location_id: pickup_location.id)

          expect(cart).to receive(:recalculate_for_address_change!)

          described_class.call(cart: cart, params: { preferred_stock_location_id: '' })
        end

        it 'does not rebuild proposals when the same location is sent again' do
          cart.update!(preferred_stock_location_id: pickup_location.id)

          expect(cart).not_to receive(:recalculate_for_address_change!)

          described_class.call(cart: cart, params: { preferred_stock_location_id: pickup_location.prefixed_id })
        end

        it 'builds collectable pickup proposals for a cart with no shipping address' do
          create(:pickup_delivery_method, store: store)
          # Ship-to-store counter: stock ships from the warehouse to the
          # counter, so the warehouse-sourced package is collectable.
          pickup_location.update!(pickup_stock_policy: 'any')
          no_address_cart = create(:cart_with_line_items, customer: user, store: store, ship_address: nil)

          result = described_class.call(
            cart: no_address_cart,
            params: { email: 'pickup@example.com', preferred_stock_location_id: pickup_location.prefixed_id }
          )

          expect(result).to be_success
          fulfillments = result.value.reload.fulfillments
          expect(fulfillments).to be_present
          expect(fulfillments.flat_map(&:delivery_rates).map(&:delivery_method)).to all(be_pickup)
        end
      end

      describe 'updating currency' do
        context 'with supported currency' do
          let(:params) { { currency: 'EUR' } }

          it 'updates the currency' do
            expect(subject).to be_success
            expect(cart.reload.currency).to eq('EUR')
          end

          it 'is case-insensitive' do
            result = described_class.call(cart: cart, params: { currency: 'eur' })
            expect(result).to be_success
            expect(cart.reload.currency).to eq('EUR')
          end
        end

        context 'with unsupported currency' do
          let(:params) { { currency: 'JPY' } }

          it 'returns failure' do
            expect(subject).to be_failure
          end

          it 'does not change the currency' do
            subject
            expect(cart.reload.currency).to eq('USD')
          end
        end

        context 'auto-switches market to match currency' do
          let(:us_country) { Spree::Country.by_iso('US') }
          let(:de_country) { create(:country, iso: 'DE', name: 'Germany') }
          let!(:us_market) { store.default_market }
          let!(:eu_market) { create(:market, :eu, store: store, countries: [de_country]) }
          let(:cart) { create(:cart_with_line_items, customer: user, store: store, market: us_market, currency: 'USD') }

          it 'switches market when currency changes' do
            result = described_class.call(cart: cart, params: { currency: 'EUR' })

            expect(result).to be_success
            expect(cart.reload.currency).to eq('EUR')
            expect(cart.market).to eq(eu_market)
          end

          it 'does not switch market when currency matches current market' do
            result = described_class.call(cart: cart, params: { currency: 'USD' })

            expect(result).to be_success
            expect(cart.reload.market).to eq(us_market)
          end

          it 'does not switch market when market_id is explicitly provided' do
            result = described_class.call(cart: cart, params: { currency: 'EUR', market_id: us_market.prefixed_id })

            expect(result).to be_success
            expect(cart.reload.market).to eq(us_market)
          end

          it 'keeps the current market when no market exists for the currency' do
            # GBP is store-supported via the legacy column; without a GBP
            # market the cart keeps its current market.
            result = described_class.call(cart: cart, params: { currency: 'GBP' })

            expect(result).to be_success
            expect(cart.reload.currency).to eq('GBP')
            expect(cart.market).to eq(us_market)
          end
        end
      end

      describe 'updating market' do
        let(:us_country) { Spree::Country.by_iso('US') }
        let(:de_country) { create(:country, iso: 'DE', name: 'Germany') }
        # The store's bootstrap market already owns the US country.
        let!(:us_market) { store.default_market }
        let!(:eu_market) { create(:market, :eu, store: store, countries: [de_country]) }

        context 'with valid market_id' do
          let(:params) { { market_id: eu_market.prefixed_id } }

          it 'updates the market' do
            expect(subject).to be_success
            expect(cart.reload.market).to eq(eu_market)
          end
        end

        context 'with invalid market_id' do
          let(:params) { { market_id: 'mkt_invalid' } }

          it 'raises RecordNotFound' do
            expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end

        context 'when shipping address country is not in the new market' do
          let!(:us_state) { Spree::State.resolve(us_country.iso, 'NY') }
          let(:us_address) { create(:address, country: us_country, state: us_state) }
          let(:cart) { create(:cart_with_line_items, customer: user, store: store, market: us_market, ship_address: us_address, email: 'buyer@example.com') }
          let(:params) { { market_id: eu_market.prefixed_id } }

          it 'clears the shipping address' do
            expect(cart.ship_address).to be_present
            expect(subject).to be_success
            expect(cart.reload.ship_address).to be_nil
          end

          it 'drops delivery proposals built for the cleared address' do
            cart.rebuild_fulfillments!
            expect(cart.fulfillments).to be_present
            expect(subject).to be_success
            expect(cart.reload.fulfillments).to be_empty
          end
        end

        context 'when shipping address country is in the new market' do
          let(:de_address) { create(:address, country: de_country) }
          let(:cart) { create(:cart_with_line_items, customer: user, store: store, market: us_market, ship_address: de_address) }
          let(:params) { { market_id: eu_market.prefixed_id } }

          it 'keeps the shipping address' do
            expect(subject).to be_success
            expect(cart.reload.ship_address).to eq(de_address)
          end
        end
      end

      describe 'updating addresses' do
        let(:country) { Spree::Country.by_iso('US') }
        let!(:state) { Spree::State.resolve(country.iso, 'NY') }

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
                  country_code: 'US',
                  state_abbr: 'NY',
                  phone: '555-1234'
                }
              }
            end

            it 'creates a new address' do
              expect(subject).to be_success
              address = cart.reload.public_send(address_key)
              expect(address.first_name).to eq('John')
              expect(address.last_name).to eq('Doe')
              expect(address.address1).to eq('123 Main St')
              expect(address.city).to eq('New York')
              expect(address.postal_code).to eq('10001')
              expect(address.country.iso).to eq('US')
              expect(address.state.abbr).to eq('NY')
            end

            context 'when the cart is fully covered by store credit payment' do
              before do
                create(:store_credit_payment, cart: cart, amount: cart.total)
              end

              it 'does not auto-complete the cart' do
                expect(subject).to be_success
                expect(cart.reload.completed?).to be(false)
              end
            end
          end

          context 'with existing address by nested id' do
            let(:existing_address) { create(:address, user: user) }
            let(:params) { { address_key => { id: existing_address.prefixed_id } } }

            it 'uses the existing address' do
              expect(subject).to be_success
              expect(cart.reload.public_send(address_id_key)).to eq(existing_address.id)
            end
          end

          context 'with top-level address_id parameter' do
            let(:existing_address) { create(:address, user: user) }
            let(:params) { { address_id_key => existing_address.prefixed_id } }

            it 'uses the existing address' do
              expect(subject).to be_success
              expect(cart.reload.public_send(address_id_key)).to eq(existing_address.id)
            end
          end
        end

        describe 'shipping_address' do
          include_examples 'address update', :shipping_address

          describe 'delivery proposals' do
            let(:params) do
              {
                shipping_address: {
                  first_name: 'John', last_name: 'Doe',
                  address1: '123 Main St', city: 'New York',
                  postal_code: '10001', country_code: 'US', state_abbr: 'NY',
                  phone: '555-1234'
                }
              }
            end

            context 'when the cart is already mid-checkout' do
              let(:cart) { create(:cart_with_line_items, customer: user, store: store, email: 'buyer@example.com', ship_address: create(:address, user: user)) }

              it 'rebuilds delivery proposals for the new address' do
                expect(subject).to be_success
                expect(cart.reload.fulfillments).to be_present
              end
            end

            context 'when the cart is still in the shopping phase' do
              it 'builds delivery proposals once the address arrives' do
                expect(subject).to be_success
                expect(cart.reload.fulfillments).to be_present
              end
            end
          end

          context 'with top-level shipping_address_id' do
            let(:existing_address) { create(:address, user: user) }
            let(:params) { { shipping_address_id: existing_address.prefixed_id } }

            it 'recalculates when shipping address is picked by id' do
              expect(cart).to receive(:recalculate_for_address_change!)

              expect(subject).to be_success
              expect(cart.reload.ship_address_id).to eq(existing_address.id)
            end
          end
        end

        describe 'billing_address' do
          include_examples 'address update', :billing_address

          context 'with top-level billing_address_id' do
            let(:existing_bill) { create(:address, user: user) }
            let(:other_bill) { create(:address, user: user) }
            let(:cart) do
              create(
                :cart_with_line_items,
                customer: user,
                store: store,
                currency: 'USD',
                bill_address: existing_bill
              )
            end

            context 'when tax is computed from the billing address' do
              before { stub_store_preferences(store, tax_using_ship_address: false) }

              it 'recalculates when the tax address is picked by id' do
                expect(cart).to receive(:recalculate_for_address_change!)

                result = described_class.call(cart: cart, params: { billing_address_id: other_bill.prefixed_id })

                expect(result).to be_success
                expect(cart.reload.bill_address_id).to eq(other_bill.id)
              end
            end

            context 'when tax is computed from the shipping address' do
              before { stub_store_preferences(store, tax_using_ship_address: true) }

              it 'does not rebuild delivery proposals' do
                cart.rebuild_fulfillments!
                fulfillment_ids = cart.fulfillments.pluck(:id)

                expect(cart).not_to receive(:recalculate_for_address_change!)

                result = described_class.call(cart: cart, params: { billing_address_id: other_bill.prefixed_id })

                expect(result).to be_success
                expect(cart.reload.fulfillments.pluck(:id)).to eq(fulfillment_ids)
              end
            end
          end
        end
      end

      describe 'default address filling on checkout entry' do
        let(:default_bill) { create(:address, user: user) }
        let(:default_ship) { create(:address, user: user) }
        let(:cart) { create(:cart_with_line_items, customer: user, store: store) }

        before { user.update!(bill_address: default_bill, ship_address: default_ship) }

        it 'fills blank slots from the customer saved defaults once in checkout' do
          described_class.call(cart: cart, params: { email: 'buyer@example.com' })

          expect(cart.reload.bill_address_id).to eq(default_bill.id)
          expect(cart.ship_address_id).to eq(default_ship.id)
        end

        it 'never fills before checkout begins' do
          described_class.call(cart: cart, params: { customer_note: 'gift please' })

          expect(cart.reload.bill_address_id).to be_nil
          expect(cart.ship_address_id).to be_nil
        end

        it 'does not overwrite an explicitly provided address' do
          explicit = create(:address, user: user)
          described_class.call(cart: cart, params: { email: 'buyer@example.com', shipping_address_id: explicit.prefixed_id })

          expect(cart.reload.ship_address_id).to eq(explicit.id)
          expect(cart.bill_address_id).to eq(default_bill.id)
        end

        it 'does nothing for guest carts' do
          guest_cart = create(:cart_with_line_items, store: store, customer: nil)

          described_class.call(cart: guest_cart, params: { email: 'guest@example.com' })

          expect(guest_cart.reload.ship_address_id).to be_nil
        end
      end

      describe 'billing address does not reset checkout state' do
        let(:country) { Spree::Country.by_iso('US') }
        let!(:state) { Spree::State.resolve(country.iso, 'NY') }
        let(:cart) { create(:cart_with_line_items, customer: user, store: store, email: 'buyer@example.com', ship_address: create(:address, user: user)) }

        let(:params) do
          {
            billing_address: {
              first_name: 'Jane',
              last_name: 'Doe',
              address1: '456 Oak Ave',
              city: 'New York',
              postal_code: '10002',
              country_code: 'US',
              state_abbr: 'NY',
              phone: '555-9999'
            }
          }
        end

        it 'preserves existing delivery proposals' do
          cart.rebuild_fulfillments!
          fulfillment_ids = cart.fulfillments.pluck(:id)
          expect(fulfillment_ids).not_to be_empty

          expect(subject).to be_success

          expect(cart.reload.fulfillments.pluck(:id)).to eq(fulfillment_ids)
        end
      end

      describe 'use_shipping (billing same as shipping)' do
        let(:country) { Spree::Country.by_iso('US') }
        let!(:state) { Spree::State.resolve(country.iso, 'NY') }

        let(:shipping_address) do
          {
            first_name: 'John',
            last_name: 'Doe',
            address1: '123 Main St',
            city: 'New York',
            postal_code: '10001',
            country_code: 'US',
            state_abbr: 'NY',
            phone: '555-1234'
          }
        end

        it 'copies shipping address to billing address' do
          # First set a shipping address
          result = described_class.call(cart: cart, params: { shipping_address: shipping_address })
          expect(result).to be_success

          # Then use_shipping to copy it to billing
          result = described_class.call(cart: cart, params: { use_shipping: true })
          expect(result).to be_success

          cart.reload
          expect(cart.bill_address).to be_present
          expect(cart.bill_address.first_name).to eq('John')
          expect(cart.bill_address.address1).to eq('123 Main St')
          expect(cart.bill_address.postal_code).to eq('10001')
        end

        it 'works when set alongside shipping address in the same request' do
          params = { shipping_address: shipping_address, use_shipping: true }
          result = described_class.call(cart: cart, params: params)
          expect(result).to be_success

          cart.reload
          expect(cart.ship_address.first_name).to eq('John')
          expect(cart.bill_address.first_name).to eq('John')
          expect(cart.bill_address.address1).to eq(cart.ship_address.address1)
        end

        it 'does not copy when use_shipping is false' do
          # Set shipping address first
          described_class.call(cart: cart, params: { shipping_address: shipping_address })
          original_bill_address_id = cart.reload.bill_address_id

          result = described_class.call(cart: cart, params: { use_shipping: false })
          expect(result).to be_success
          expect(cart.reload.bill_address_id).to eq(original_bill_address_id)
        end
      end

      describe 'address ownership' do
        let(:other_user) { create(:user) }
        let(:other_users_address) { create(:address, user: other_user) }

        shared_examples 'ignores other users address' do |address_type|
          context "when using another user's address for #{address_type}" do
            let(:params) { { address_type => { id: other_users_address.prefixed_id } } }

            it 'ignores the address and keeps original' do
              original_address_id = cart.public_send(:"#{address_type}_id")
              expect(subject).to be_success
              expect(cart.reload.public_send(:"#{address_type}_id")).to eq(original_address_id)
              expect(cart.public_send(:"#{address_type}_id")).not_to eq(other_users_address.id)
            end
          end

          context "when using another user's address via #{address_type}_id" do
            let(:params) { { :"#{address_type}_id" => other_users_address.prefixed_id } }

            it 'ignores the address and keeps original' do
              original_address_id = cart.public_send(:"#{address_type}_id")
              expect(subject).to be_success
              expect(cart.reload.public_send(:"#{address_type}_id")).to eq(original_address_id)
              expect(cart.public_send(:"#{address_type}_id")).not_to eq(other_users_address.id)
            end
          end
        end

        include_examples 'ignores other users address', :shipping_address
        include_examples 'ignores other users address', :billing_address

        context 'when the cart has no user (guest cart)' do
          let(:cart) { create(:cart_with_line_items, customer: nil, store: store) }
          let(:params) { { shipping_address_id: other_users_address.prefixed_id } }

          it 'ignores address_id params and keeps existing address' do
            original_address_id = cart.ship_address_id
            expect(subject).to be_success
            expect(cart.reload.ship_address_id).to eq(original_address_id)
          end
        end
      end

      describe 'updating metadata' do
        let(:params) { { metadata: { 'erp_id' => '12345', 'source' => 'mobile' } } }

        it 'merges metadata into the cart' do
          expect(subject).to be_success
          expect(cart.reload.metadata).to include('erp_id' => '12345', 'source' => 'mobile')
        end

        context 'with existing metadata' do
          before { cart.update!(metadata: { 'existing_key' => 'existing_value' }) }

          let(:params) { { metadata: { 'new_key' => 'new_value' } } }

          it 'merges without removing existing keys' do
            expect(subject).to be_success
            expect(cart.reload.metadata).to include('existing_key' => 'existing_value', 'new_key' => 'new_value')
          end
        end
      end

      describe 'updating multiple fields' do
        let(:country) { Spree::Country.by_iso('US') }
        let!(:state) { Spree::State.resolve(country.iso, 'NY') }

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
              country_code: 'US',
              state_abbr: 'NY'
            }
          }
        end

        it 'updates all fields in a single transaction' do
          expect(subject).to be_success
          cart.reload
          expect(cart.email).to eq('customer@example.com')
          expect(cart.customer_note).to eq('Handle with care')
          expect(cart.shipping_address.first_name).to eq('John')
        end
      end

      describe 'setting line items' do
        let(:variant) { create(:variant) }

        before do
          variant.stock_levels.first.update!(count_on_hand: 10)
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

          it 'adds line items to the cart' do
            expect(subject).to be_success
            cart.reload
            line_item = cart.line_items.find_by(variant: variant)
            expect(line_item).to be_present
            expect(line_item.quantity).to eq(2)
          end
        end

        context 'with existing line item (upsert)' do
          let!(:existing_line_item) { cart.line_items.first }
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
            original_address_id = cart.ship_address_id
            expect(subject).to be_success
            expect(cart.reload.ship_address_id).to eq(original_address_id)
          end
        end

        context 'when the cart save fails' do
          let(:params) { { email: 'new@example.com' } }

          before do
            allow(cart).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(cart))
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
          expect(cart.reload.email).to eq('string_key@example.com')
        end
      end

      describe 'stock reservations' do
        subject { described_class.call(cart: cart, params: params) }

        let(:cart) { create(:cart_with_line_items, store: store) }
        let(:country) { Spree::Country.by_iso('US') }
        let!(:us_state) { Spree::State.resolve(country.iso, 'NY') }
        let!(:zone) { create(:zone) }
        let!(:shipping_method) { create(:shipping_method) }
        let(:address_params) do
          {
            first_name: 'Buyer', last_name: 'McGee',
            address1: '1 Test St', city: 'New York',
            postal_code: '10001', country_code: 'US', state_abbr: 'NY',
            phone: '555-0100'
          }
        end

        before do
          cart.line_items.first.variant.stock_levels.first.update!(backorderable: false)
          cart.line_items.first.variant.stock_levels.first.set_count_on_hand(20)
        end

        context 'cart → checkout transition' do
          let(:params) { { email: 'buyer@example.com', shipping_address: address_params } }

          it 'creates reservations when entering checkout' do
            expect { subject }.to change { Spree::StockReservation.where(cart_id: cart.id).count }.by_at_least(1)
            expect(cart.reload.in_checkout?).to be(true)
          end
        end

        context 'in-checkout mutation' do
          before do
            described_class.call(cart: cart, params: { email: 'buyer@example.com', shipping_address: address_params })
          end

          let(:params) { { customer_note: 'please ring bell' } }

          it 'extends existing reservations' do
            original_expiry = Spree::StockReservation.where(cart_id: cart.id).maximum(:expires_at)

            Timecop.freeze(2.minutes.from_now) do
              described_class.call(cart: cart, params: params)
            end

            expect(Spree::StockReservation.where(cart_id: cart.id).maximum(:expires_at)).to be > original_expiry
          end
        end

        # Reverting to the `cart` state from inside Update isn't reachable via
        # the public params shape — `revert_to_address_state` only goes back to
        # `address`, never all the way to `cart`. The `cart?` branch of
        # sync_stock_reservations (Release) is exercised by Cart::Empty and
        # Cart::Destroy specs.

        context 'when Reserve fails with insufficient stock' do
          let(:params) { { email: 'changed@example.com', shipping_address: address_params } }

          before do
            # Bump line_item quantity above what stock_level can satisfy so that
            # select_stock_level still picks the item (count_on_hand > 0) but
            # the availability check fails.
            cart.line_items.first.update_column(:quantity, 5)
            cart.line_items.first.variant.stock_levels.first.set_count_on_hand(2)
          end

          it 'returns failure and rolls back the cart update' do
            previous_email = cart.email
            result = subject

            expect(result).to be_failure
            expect(result.error.to_s).to include('available')
            expect(cart.reload.email).to eq(previous_email)
            expect(Spree::StockReservation.where(cart_id: cart.id)).to be_empty
          end
        end
      end

      describe 'when the cart cannot be delivered' do
        subject { described_class.call(cart: cart, params: params) }

        let!(:cart) { create(:cart_with_line_items, store: store) }
        let!(:shipping_method) { create(:shipping_method) }
        let(:country) { Spree::Country.by_iso('US') }
        let!(:us_state) { Spree::State.resolve(country.iso, 'NY') }
        let(:params) do
          { email: 'buyer@example.com',
            shipping_address: {
              first_name: 'Buyer', last_name: 'McGee',
              address1: '1 Test St', city: 'New York',
              postal_code: '10001', country_code: 'US', state_abbr: 'NY',
              phone: '555-0100'
            } }
        end
        # a profile with no delivery methods cannot fulfill anything
        let(:empty_profile) { create(:delivery_profile, store: store, name: "Empty #{SecureRandom.hex(4)}") }

        before do
          cart.line_items.each { |line_item| line_item.variant.product.update!(delivery_profile: empty_profile) }
          cart.reload
        end

        it 'leaves the cart with no fulfillments' do
          expect(subject).to be_success
          expect(cart.reload.fulfillments).to be_empty
        end

        it 'keeps the delivery requirement unmet' do
          subject
          requirements = Spree::Checkout::Requirements.new(cart.reload).call
          expect(requirements.map { |requirement| requirement[:step] }).to include('delivery')
        end
      end

    end

    describe 'when a strict store cannot confirm prices' do
      let(:store) { @default_store }
      let(:cart) { create(:cart, store: store) }
      let(:variant) { create(:variant, price: 20) }

      let(:failing_provider) do
        Class.new(Spree::PricingProvider::Base) do
          def self.key = 'contract'
          def price_for(_context) = raise(Timeout::Error)
        end
      end

      before do
        create(:line_item, order: cart, variant: variant, quantity: 1)
        Spree.pricing_providers << failing_provider
        stub_store_preferences(store, pricing_provider: 'contract')
      end

      after { Spree.pricing_providers.delete(failing_provider) }

      # The address change and the prices are one decision: committing a new
      # destination while refusing to price for it would leave the cart showing
      # figures nobody stood behind.
      it 'rolls the address change back rather than committing it unpriced' do
        result = described_class.call(
          cart: cart,
          params: { shipping_address: { firstname: 'Ada', lastname: 'Lovelace', address1: '1 Main St',
                                        city: 'New York', zipcode: '10001', phone: '555-0100',
                                        country_code: 'US', state_code: 'NY' } }
        )

        expect(result).to be_failure
        # The object handed back must not still carry the rolled-back address:
        # a caller that renders it would show an address the database refused.
        expect(cart.ship_address_id).to be_nil
        expect(cart.reload.shipping_address).to be_nil
      end
    end

    # An abandoned direct upload leaves the blob row behind without its bytes,
    # and the buyer's client may still send back the signed id it was handed.
    describe 'a purchase order document whose upload never completed' do
      let(:orphan_blob) do
        ActiveStorage::Blob.create_before_direct_upload!(
          filename: 'po.pdf', byte_size: 12, checksum: 'x' * 22,
          content_type: 'application/pdf', service_name: Spree.private_storage_service_name
        )
      end

      it 'reports a readable message instead of an exception class name' do
        result = described_class.call(cart: cart, params: { po_document: orphan_blob.signed_id })

        expect(result).to be_failure
        expect(result.error.to_s).to include(Spree.t(:po_document_upload_incomplete))
        expect(result.error.to_s).not_to include('ActiveStorage')
      end
    end

    describe 'a purchase order document attached without the Unix file command' do
      let(:blob) do
        ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new('%PDF-1.4 purchase order'),
          filename: 'po.pdf',
          content_type: 'application/pdf',
          service_name: Spree.private_storage_service_name
        )
      end

      it 'attaches the file' do
        expect(Open3).not_to receive(:capture2)

        result = described_class.call(cart: cart, params: { po_document: blob.signed_id })

        expect(result).to be_success
        expect(cart.reload.po_document).to be_attached
      end
    end

    describe 'a purchase order document whose bytes do not match the declared type' do
      let(:blob) do
        ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new("#!/bin/sh\nrm -rf /\n"),
          filename: 'po.pdf',
          content_type: 'application/pdf',
          identify: false,
          service_name: Spree.private_storage_service_name
        )
      end

      it 'refuses the attach' do
        result = described_class.call(cart: cart, params: { po_document: blob.signed_id })

        expect(result).to be_failure
        expect(result.error.to_s).to include(Spree.t(:attachment_content_type_mismatch))
        expect(cart.reload.po_document).not_to be_attached
      end
    end
  end
end
