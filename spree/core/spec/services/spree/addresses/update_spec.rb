require 'spec_helper'

RSpec.describe Spree::Addresses::Update do
  subject { described_class }

  let(:user) { create(:user) }
  let(:country) { create(:country) }
  let(:state) { create(:state, country: country) }
  let!(:address) { create(:address, customer: user) }
  let(:result) { subject.call(address: address, address_params: new_address_params, order: order) }
  let(:value) { result.value }
  let(:order) { nil }

  describe '#call' do
    context 'with valid params' do
      let(:new_address_params) do
        {
          firstname: FFaker::Name.first_name,
          lastname: FFaker::Name.last_name,
          address1: FFaker::Address.street_address,
          city: FFaker::Address.city,
          phone: FFaker::PhoneNumber.phone_number,
          postal_code: Spree::TestingSupport::CountryPool.postal_code_for(country.iso),
          state_name: state.name,
          country_code: country.iso
        }
      end

      shared_examples 'updating with same params' do
        context 'when params are the same' do
          before { result }

          it 'does not update address' do
            expect { subject.call(address: address, address_params: new_address_params, order: order) }.not_to change { address.reload }
          end

          it 'does not create new address' do
            expect { subject.call(address: address, address_params: new_address_params, order: order) }.not_to change { Spree::Address.count }
          end

          it 'returns success' do
            expect(subject.call(address: address, address_params: new_address_params, order: order)).to be_success
          end

          it 'does not update address nor create when attribute changed from nil to blank string' do
            result.value.update(address2: nil)

            new_address_params[:address2] = ''
            expect { subject.call(address: address, address_params: new_address_params, order: order) }.not_to change { address.reload }
            expect { subject.call(address: address, address_params: new_address_params, order: order) }.not_to change { Spree::Address.count }
          end

          it 'does not update address nor create when attribute changed only in case' do
            result.value.update(address1: '123 Main St')

            new_address_params[:address1] = '123 MAIN ST'
            expect { subject.call(address: address, address_params: new_address_params, order: order) }.not_to change { address.reload }
            expect { subject.call(address: address, address_params: new_address_params, order: order) }.not_to change { Spree::Address.count }
          end
        end

        context 'when user only sets the address as default shipping' do
          let(:result) { subject.call(address: address, address_params: {}, order: order, default_shipping: true) }
          let!(:previous_address) { create(:address, customer: user) }

          before { user.reload.update(ship_address: previous_address) }

          it 'updates user\'s ship address' do
            expect(user.ship_address_id).to eq(previous_address.id)
            result
            expect(user.reload.ship_address_id).to eq(value.id)
          end
        end

        context 'when user only sets the address as default billing' do
          let(:result) { subject.call(address: address, address_params: {}, order: order, default_billing: true) }
          let!(:previous_address) { create(:address, customer: user) }

          before { user.reload.update(bill_address: previous_address) }

          it 'updates user\'s bill address' do
            expect(user.bill_address_id).to eq(previous_address.id)
            result
            expect(user.reload.bill_address_id).to eq(value.id)
          end
        end
      end

      context 'when address is editable' do
        it 'updates address' do
          expect { result }.not_to change(Spree::Address, :count)
          expect(result).to be_success
          # state_name is promoted to the matching state record, so it clears
          expect(value).to have_attributes(new_address_params.except(:state_name))
          expect(value.country).to eq(country)
          expect(value.state).to eq(state)
        end

        context 'when user sets address as default shipping' do
          let(:result) { subject.call(address: address, address_params: new_address_params, order: order, default_shipping: true) }
          let!(:previous_address) { create(:address, customer: user) }

          before { user.reload.update(ship_address: previous_address) }

          it 'updates user\'s ship address' do
            expect(user.ship_address_id).to eq(previous_address.id)
            result
            expect(user.reload.ship_address_id).to eq(value.id)
          end
        end

        context 'when user sets address as default billing' do
          let(:result) { subject.call(address: address, address_params: new_address_params, order: order, default_billing: true) }
          let!(:previous_address) { create(:address, customer: user) }

          before { user.reload.update(bill_address: previous_address) }

          it 'updates user\'s bill address' do
            expect(user.bill_address_id).to eq(previous_address.id)
            result
            expect(user.reload.bill_address_id).to eq(value.id)
          end
        end

        context 'when order is passed' do
          let(:order) { create(:order, customer: user, state: 'delivery', ship_address: address, bill_address: address) }

          it 'updates order to address state' do
            expect { result }.not_to raise_error
          end
        end

        it_behaves_like 'updating with same params'
      end

      context 'when address is uneditable' do
        let!(:completed_order) { create(:completed_order_with_totals, customer: user, ship_address: address, bill_address: address) }

        context 'when there have been created same address with new params' do
          let!(:same_address) { user.addresses.create(new_address_params.merge(country_code: country.iso, state_code: state.abbr)) }

          context 'when is not deleted' do
            it 'takes that address' do
              expect(result.value.id).to eq same_address.id
            end
          end

          context 'when its soft deleted' do
            before { same_address.update!(deleted_at: Time.current) }

            it 'creates new address' do
              expect { result }.to change(Spree::Address, :count).by 1
              expect { result }.not_to change { same_address.reload }
            end
          end
        end

        context 'when there is no such existing address with given params' do
          it 'creates new address and soft-deletes the previous one' do
            expect { result }.to change(Spree::Address.unscoped, :count).by 1
            expect(result).to be_success
            # state_name is promoted to the matching state record, so it clears
            expect(value).to have_attributes(new_address_params.except(:state_name))
            expect(value.id).not_to eq(address.id)
            expect(value.country).to eq(country)
            expect(value.state).to eq(state)
            expect(value.user).to eq(user)
            expect(address.deleted_at).not_to be_nil
          end

          context 'when the old address was set as default billing' do
            let(:other_address) { create(:address, customer: user) }

            before { user.update!(bill_address: address, ship_address: other_address) }

            it 'sets the new address as default billing' do
              expect(result).to be_success

              expect(address.deleted_at).to be_present

              expect(user.reload.bill_address).to eq(value)
              expect(user.ship_address).to eq(other_address)
            end
          end

          context 'when the old address was set as default shipping' do
            let(:other_address) { create(:address, customer: user) }

            before { user.update!(bill_address: other_address, ship_address: address) }

            it 'sets the new address as default shipping' do
              expect(result).to be_success

              expect(address.deleted_at).to be_present

              expect(user.reload.ship_address).to eq(value)
              expect(user.bill_address).to eq(other_address)
            end
          end
        end

        context 'when user sets address as default shipping' do
          let(:result) { subject.call(address: address, address_params: new_address_params, order: order, default_shipping: true) }

          before { user.reload.update(ship_address: address) }

          it 'updates user\'s ship address' do
            expect(user.ship_address_id).to eq(address.id)
            result
            expect(address.id).not_to eq(value.id)
            expect(user.reload.ship_address_id).to eq(value.id)
          end
        end

        context 'when user sets address as default billing' do
          let(:result) { subject.call(address: address, address_params: new_address_params, order: order, default_billing: true) }

          before { user.reload.update(bill_address: address) }

          it 'updates user\'s bill address' do
            expect(user.bill_address_id).to eq(address.id)
            result
            expect(address.id).not_to eq(value.id)
            expect(user.reload.bill_address_id).to eq(value.id)
          end
        end

        context 'when order with deleted address is passed' do
          let(:order) { create(:order, customer: user, state: 'delivery', ship_address: address, bill_address: address) }

          it 'updates order to address state' do
            expect { result }.not_to raise_error
          end

          it 'updates order ship address' do
            result
            expect(order.reload.ship_address_id).to eq(value.id)
          end

          it 'updates order bill address' do
            result
            expect(order.reload.bill_address_id).to eq(value.id)
          end
        end

        context 'when a separate incomplete order shares the address' do
          let!(:incomplete_order) { create(:order, customer: user, ship_address: address, bill_address: address) }

          it 'repoints the incomplete order to the new address and moves it to the address step' do
            result

            expect(incomplete_order.reload.ship_address_id).to eq(value.id)
            expect(incomplete_order.bill_address_id).to eq(value.id)
          end

          it 'keeps the completed order on the original, soft-deleted address' do
            result

            expect(completed_order.reload.ship_address_id).to eq(address.id)
            expect(completed_order.bill_address_id).to eq(address.id)
            expect(address.reload.deleted_at).to be_present
          end

          it "does not repoint another user's order sharing the address" do
            other_order = create(:order, customer: create(:user), ship_address: address, bill_address: address, state: 'delivery')

            result

            expect(other_order.reload.ship_address_id).to eq(address.id)
            expect(other_order.bill_address_id).to eq(address.id)
            expect(other_order.reload.completed_at).to be_nil
          end
        end

        context 'when soft-deleting the previous address fails' do
          before do
            allow(address).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed.new('failed', address))
          end

          it 'rolls back the address replacement and returns a failure' do
            expect { result }.not_to change(Spree::Address.unscoped, :count)
            expect(result).to be_failure
            expect(result.value).to eq(address)
          end
        end

        it_behaves_like 'updating with same params'
      end

      context 'when a guest cart shares an immutable address' do
        let(:address) { create(:address) }
        let!(:completed_guest_order) do
          create(:order, customer: nil, email: 'guest-complete@example.com', completed_at: Time.current,
                         ship_address: address, bill_address: address)
        end
        let!(:guest_cart) do
          create(:order, customer: nil, email: 'guest-cart@example.com', ship_address: address, bill_address: address)
        end

        it 'repoints the guest cart to the copy and keeps the completed order on the original' do
          expect(result).to be_success
          expect(value.id).not_to eq(address.id)
          expect(address.reload.deleted_at).to be_present

          expect(guest_cart.reload.ship_address_id).to eq(value.id)
          expect(guest_cart.bill_address_id).to eq(value.id)

          expect(completed_guest_order.reload.ship_address_id).to eq(address.id)
        end
      end
    end

    context 'with invalid params' do
      let(:new_address_params) do
        {
          phone: '',
          postal_code: ''
        }
      end

      it 'returns errors' do
        expect { result }.not_to change(Spree::Address, :count)
        expect(result).to be_failure

        messages = result.error.value.messages
        expect(messages).to eq( postal_code: ["can't be blank"])
      end

      context 'when the address is uneditable' do
        let!(:completed_order) { create(:completed_order_with_totals, customer: user, ship_address: address, bill_address: address) }

        it 'returns a failure and leaves the original address intact' do
          expect { result }.not_to change(Spree::Address, :count)
          expect(result).to be_failure
          expect(address.reload.deleted_at).to be_nil
        end
      end
    end
  end
  # The service used to reach for the customer behind an address, so a company
  # node's book reported success while its default pointer never moved.
  describe 'a company book entry' do
    let(:store) { @default_store }
    let(:company) { create(:company, store: store) }
    let!(:entry) { create(:company_address, owner: company, label: 'HQ') }

    it 'promotes the entry to the node default' do
      result = Spree.address_update_service.call(
        address: entry, address_params: { city: 'Shelbyville' }, default_billing: true
      )

      expect(result).to be_success
      expect(company.reload.default_bill_address_id).to eq(entry.id)
    end

    it 'moves only the pointer when nothing about the address changed' do
      result = Spree.address_update_service.call(
        address: entry, address_params: {}, default_shipping: true
      )

      expect(result).to be_success
      expect(company.reload.default_ship_address_id).to eq(entry.id)
    end
  end
end
