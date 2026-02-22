require 'spec_helper'

RSpec.describe Spree::Api::V3::Orders::Update do
  let(:store) { create(:store, supported_currencies: 'USD,EUR,GBP') }
  let(:user) { create(:user) }
  let(:order) { create(:order_with_line_items, user: user, store: store, currency: 'USD') }

  describe '#call' do
    subject { described_class.call(order: order, params: params) }

    describe 'updating email' do
      let(:params) { { email: 'new@example.com' } }

      it 'updates the order email' do
        expect(subject).to be_success
        expect(order.reload.email).to eq('new@example.com')
      end
    end

    describe 'updating special_instructions' do
      let(:params) { { special_instructions: 'Leave at the door' } }

      it 'updates the special instructions' do
        expect(subject).to be_success
        expect(order.reload.special_instructions).to eq('Leave at the door')
      end

      context 'when clearing special_instructions' do
        let(:order) { create(:order_with_line_items, user: user, store: store, special_instructions: 'Existing instructions') }

        it 'clears with empty string' do
          result = described_class.call(order: order, params: { special_instructions: '' })
          expect(result).to be_success
          expect(order.reload.special_instructions).to eq('')
        end

        it 'clears with nil' do
          result = described_class.call(order: order, params: { special_instructions: nil })
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
          result = described_class.call(order: order, params: { currency: 'eur' })
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
    end

    describe 'updating addresses' do
      let(:country) { Spree::Country.find_by(iso: 'US') || create(:country, iso: 'US') }
      let!(:state) { country.states.find_by(abbr: 'NY') || create(:state, country: country, abbr: 'NY', name: 'New York') }

      shared_examples 'address update' do |address_type|
        let(:address_key) { address_type } # :ship_address or :bill_address
        let(:address_id_key) { :"#{address_type}_id" } # :ship_address_id or :bill_address_id

        context 'with new address attributes' do
          let(:params) do
            {
              address_key => {
                firstname: 'John',
                lastname: 'Doe',
                address1: '123 Main St',
                city: 'New York',
                zipcode: '10001',
                country_iso: 'US',
                state_abbr: 'NY',
                phone: '555-1234'
              }
            }
          end

          it 'creates a new address' do
            expect(subject).to be_success
            address = order.reload.public_send(address_key)
            expect(address.firstname).to eq('John')
            expect(address.lastname).to eq('Doe')
            expect(address.address1).to eq('123 Main St')
            expect(address.city).to eq('New York')
            expect(address.zipcode).to eq('10001')
            expect(address.country.iso).to eq('US')
            expect(address.state.abbr).to eq('NY')
          end

          context 'when order has address checkout step and is past address state' do
            let(:order) { create(:order_with_line_items, user: user, store: store, state: 'delivery') }

            it 'reverts order to address state' do
              expect(subject).to be_success
              expect(order.reload.state).to eq('address')
            end
          end

          context 'when order is in cart state' do
            let(:order) { create(:order_with_line_items, user: user, store: store, state: 'cart') }

            it 'does not change order state' do
              expect(subject).to be_success
              expect(order.reload.state).to eq('cart')
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

      describe 'ship_address' do
        include_examples 'address update', :ship_address
      end

      describe 'bill_address' do
        include_examples 'address update', :bill_address
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

      include_examples 'ignores other users address', :ship_address
      include_examples 'ignores other users address', :bill_address

      context 'when order has no user (guest order)' do
        let(:order) { create(:order_with_line_items, user: nil, store: store) }
        let(:params) { { ship_address_id: other_users_address.prefixed_id } }

        it 'ignores address_id params and keeps existing address' do
          original_address_id = order.ship_address_id
          expect(subject).to be_success
          expect(order.reload.ship_address_id).to eq(original_address_id)
        end
      end
    end

    describe 'updating multiple fields' do
      let(:country) { Spree::Country.find_by(iso: 'US') || create(:country, iso: 'US') }
      let!(:state) { country.states.find_by(abbr: 'NY') || create(:state, country: country, abbr: 'NY', name: 'New York') }

      let(:params) do
        {
          email: 'customer@example.com',
          special_instructions: 'Handle with care',
          ship_address: {
            firstname: 'John',
            lastname: 'Doe',
            address1: '123 Main St',
            city: 'New York',
            zipcode: '10001',
            country_iso: 'US',
            state_abbr: 'NY'
          }
        }
      end

      it 'updates all fields in a single transaction' do
        expect(subject).to be_success
        order.reload
        expect(order.email).to eq('customer@example.com')
        expect(order.special_instructions).to eq('Handle with care')
        expect(order.ship_address.firstname).to eq('John')
      end
    end

    describe 'error handling' do
      context 'with invalid address prefix_id' do
        let(:params) { { ship_address_id: 'addr_invalid123' } }

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
