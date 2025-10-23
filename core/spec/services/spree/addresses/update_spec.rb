require 'spec_helper'

RSpec.describe Spree::Addresses::Update do
  subject { described_class }

  let(:user) { create(:user) }
  let(:country) { create(:country) }
  let(:state) { create(:state, country: country) }
  let!(:address) { create(:address, user: user) }
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
          zipcode: FFaker::AddressUS.zip_code,
          state_name: state.name,
          country_iso: country.iso
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

          context 'when setting the create_new_address_on_update param to true' do
            it 'does not create new address' do
              expect { subject.call(address: address, address_params: new_address_params, order: order, create_new_address_on_update: true) }.not_to change { Spree::Address.count }
            end
          end
        end

        context 'when user only sets the address as default shipping' do
          let(:result) { subject.call(address: address, address_params: {}, order: order, default_shipping: true) }
          let!(:previous_address) { create(:address, user: user) }

          before { user.reload.update(ship_address: previous_address) }

          it 'updates user\'s ship address' do
            expect(user.ship_address_id).to eq(previous_address.id)
            result
            expect(user.reload.ship_address_id).to eq(value.id)
          end
        end

        context 'when user only sets the address as default billing' do
          let(:result) { subject.call(address: address, address_params: {}, order: order, default_billing: true) }
          let!(:previous_address) { create(:address, user: user) }

          before { user.reload.update(bill_address: previous_address) }

          it 'updates user\'s bill address' do
            expect(user.bill_address_id).to eq(previous_address.id)
            result
            expect(user.reload.bill_address_id).to eq(value.id)
          end
        end
      end

      shared_examples 'always create a new address on update' do
        context 'when the create_new_address_on_update param is set to true' do
          let(:result) { subject.call(address: address, address_params: new_address_params, order: order, **params) }
          let(:params) { { create_new_address_on_update: true } }

          it 'creates a new address and keeps the previous one' do
            expect { result }.to change(Spree::Address, :count).by(1)

            expect(result).to be_success
            expect(value).to have_attributes(new_address_params)
            expect(value.id).not_to eq(address.id)
            expect(value.country).to eq(country)
            expect(value.state).to eq(state)
            expect(value.user).to eq(user)
            expect(address.deleted_at).to be_nil
          end

          context 'with a user' do
            before do
              new_address_params.merge!(user_id: user.id)
              user.update!(ship_address: address, bill_address: address)
            end

            it "doesn't change the user's bill and ship addresses by default" do
              expect(result).to be_success

              expect(user.reload.bill_address).to eq(address.reload)
              expect(user.ship_address).to eq(address)
            end

            context 'when the default_billing param is set to true' do
              let(:params) { { create_new_address_on_update: true, default_billing: true } }

              it 'changes user\'s bill address' do
                expect(result).to be_success

                expect(user.reload.bill_address).to eq(value)
                expect(user.ship_address).to eq(address.reload)
              end
            end

            context 'when the default_shipping param is set to true' do
              let(:params) { { create_new_address_on_update: true, default_shipping: true } }

              it 'changes user\'s ship address' do
                expect(result).to be_success

                expect(user.reload.ship_address).to eq(value)
                expect(user.bill_address).to eq(address.reload)
              end
            end
          end

          context 'with an order' do
            let(:order) { create(:order, user: user, state: 'delivery', ship_address: address, bill_address: address) }

            it "doesn't change the order addresses" do
              expect(result).to be_success

              expect(order.reload.bill_address).to eq(address)
              expect(order.reload.ship_address).to eq(address)
            end
          end
        end
      end

      context 'when address is editable' do
        it 'updates address' do
          expect { result }.not_to change(Spree::Address, :count)
          expect(result).to be_success
          expect(value).to have_attributes(new_address_params)
          expect(value.country).to eq(country)
          expect(value.state).to eq(state)
        end

        context 'when user sets address as default shipping' do
          let(:result) { subject.call(address: address, address_params: new_address_params, order: order, default_shipping: true) }
          let!(:previous_address) { create(:address, user: user) }

          before { user.reload.update(ship_address: previous_address) }

          it 'updates user\'s ship address' do
            expect(user.ship_address_id).to eq(previous_address.id)
            result
            expect(user.reload.ship_address_id).to eq(value.id)
          end
        end

        context 'when user sets address as default billing' do
          let(:result) { subject.call(address: address, address_params: new_address_params, order: order, default_billing: true) }
          let!(:previous_address) { create(:address, user: user) }

          before { user.reload.update(bill_address: previous_address) }

          it 'updates user\'s bill address' do
            expect(user.bill_address_id).to eq(previous_address.id)
            result
            expect(user.reload.bill_address_id).to eq(value.id)
          end
        end

        context 'when order is passed' do
          let(:order) { create(:order, user: user, state: 'delivery', ship_address: address, bill_address: address) }

          it 'updates order to address state' do
            expect { result }.to change { order.reload.state }.from('delivery').to('address')
          end
        end

        it_behaves_like 'updating with same params'
        include_examples 'always create a new address on update'
      end

      context 'when address is uneditable' do
        let!(:completed_order) { create(:completed_order_with_totals, user: user, ship_address: address, bill_address: address) }

        context 'when there have been created same address with new params' do
          let!(:same_address) { user.addresses.create(new_address_params.except(:country_iso).merge(country: country, state: state)) }

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
            expect(value).to have_attributes(new_address_params)
            expect(value.id).not_to eq(address.id)
            expect(value.country).to eq(country)
            expect(value.state).to eq(state)
            expect(value.user).to eq(user)
            expect(address.deleted_at).not_to be_nil
          end

          context 'when the old address was set as default billing' do
            let(:other_address) { create(:address, user: user) }

            before { user.update!(bill_address: address, ship_address: other_address) }

            it 'sets the new address as default billing' do
              expect(result).to be_success

              expect(address.deleted_at).to be_present

              expect(user.reload.bill_address).to eq(value)
              expect(user.ship_address).to eq(other_address)
            end
          end

          context 'when the old address was set as default shipping' do
            let(:other_address) { create(:address, user: user) }

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
          let(:order) { create(:order, user: user, state: 'delivery', ship_address: address, bill_address: address) }

          it 'updates order to address state' do
            expect { result }.to change { order.reload.state }.from('delivery').to('address')
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

        it_behaves_like 'updating with same params'
        include_examples 'always create a new address on update'
      end
    end

    context 'with invalid params' do
      let(:new_address_params) do
        {
          phone: '',
          zipcode: ''
        }
      end

      it 'returns errors' do
        expect { result }.not_to change(Spree::Address, :count)
        expect(result).to be_failure

        messages = result.error.value.messages
        expect(messages).to eq( zipcode: ["can't be blank"])
      end
    end
  end
end
