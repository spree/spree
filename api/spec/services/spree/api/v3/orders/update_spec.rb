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

    describe 'updating ship_address' do
      let(:country) { Spree::Country.find_by(iso: 'US') || create(:country, iso: 'US') }
      let!(:state) { country.states.find_by(abbr: 'NY') || create(:state, country: country, abbr: 'NY', name: 'New York') }

      context 'with new address attributes' do
        let(:params) do
          {
            ship_address: {
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

        it 'creates a new shipping address' do
          expect(subject).to be_success
          address = order.reload.ship_address
          expect(address.firstname).to eq('John')
          expect(address.lastname).to eq('Doe')
          expect(address.address1).to eq('123 Main St')
          expect(address.city).to eq('New York')
          expect(address.zipcode).to eq('10001')
          expect(address.country.iso).to eq('US')
          expect(address.state.abbr).to eq('NY')
        end

        context 'when order has address checkout step' do
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

      context 'with existing address by prefix_id' do
        let(:existing_address) { create(:address, user: user) }
        let(:params) { { ship_address: { id: existing_address.prefix_id } } }

        it 'uses the existing address' do
          expect(subject).to be_success
          expect(order.reload.ship_address_id).to eq(existing_address.id)
        end
      end

      context 'with ship_address_id parameter' do
        let(:existing_address) { create(:address, user: user) }
        let(:params) { { ship_address_id: existing_address.prefix_id } }

        it 'uses the existing address' do
          expect(subject).to be_success
          expect(order.reload.ship_address_id).to eq(existing_address.id)
        end
      end
    end

    describe 'updating bill_address' do
      let(:country) { Spree::Country.find_by(iso: 'US') || create(:country, iso: 'US') }
      let!(:state) { country.states.find_by(abbr: 'CA') || create(:state, country: country, abbr: 'CA', name: 'California') }

      context 'with new address attributes' do
        let(:params) do
          {
            bill_address: {
              firstname: 'Jane',
              lastname: 'Smith',
              address1: '456 Oak Ave',
              city: 'Los Angeles',
              zipcode: '90001',
              country_iso: 'US',
              state_abbr: 'CA',
              phone: '555-5678'
            }
          }
        end

        it 'creates a new billing address' do
          expect(subject).to be_success
          address = order.reload.bill_address
          expect(address.firstname).to eq('Jane')
          expect(address.lastname).to eq('Smith')
          expect(address.address1).to eq('456 Oak Ave')
          expect(address.city).to eq('Los Angeles')
        end
      end

      context 'with existing address by prefix_id' do
        let(:existing_address) { create(:address, user: user) }
        let(:params) { { bill_address: { id: existing_address.prefix_id } } }

        it 'uses the existing address' do
          expect(subject).to be_success
          expect(order.reload.bill_address_id).to eq(existing_address.id)
        end
      end

      context 'with bill_address_id parameter' do
        let(:existing_address) { create(:address, user: user) }
        let(:params) { { bill_address_id: existing_address.prefix_id } }

        it 'uses the existing address' do
          expect(subject).to be_success
          expect(order.reload.bill_address_id).to eq(existing_address.id)
        end
      end
    end

    describe 'address ownership validation' do
      let(:other_user) { create(:user) }
      let(:other_users_address) { create(:address, user: other_user) }

      context 'when using another users address for ship_address' do
        let(:params) { { ship_address: { id: other_users_address.prefix_id } } }

        it 'returns failure' do
          expect(subject).to be_failure
          expect(subject.error).to be_present
        end
      end

      context 'when using another users address for bill_address' do
        let(:params) { { bill_address: { id: other_users_address.prefix_id } } }

        it 'returns failure' do
          expect(subject).to be_failure
          expect(subject.error).to be_present
        end
      end

      context 'when using guest address (no user)' do
        let(:guest_address) { create(:address, user: nil) }
        let(:params) { { ship_address_id: guest_address.prefix_id } }

        it 'allows using the address' do
          expect(subject).to be_success
          expect(order.reload.ship_address_id).to eq(guest_address.id)
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

        it 'returns failure' do
          expect(subject).to be_failure
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
