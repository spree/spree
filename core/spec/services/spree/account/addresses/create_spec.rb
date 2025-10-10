require 'spec_helper'

module Spree
  describe Account::Addresses::Create do
    subject { described_class }

    let(:user) { create(:user) }
    let(:country) { create(:country) }
    let(:state) { create(:state, country: country) }

    let(:result) { subject.call(user: user, address_params: address_params) }
    let(:value) { result.value }

    describe '#call' do
      context 'with valid params' do
        let(:address_params) do
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

        it 'creates address' do
          expect { result }.to change(Address, :count)
          expect(result).to be_success
          expect(value).to have_attributes(address_params)
          expect(value.country).to eq(country)
          expect(value.state).to eq(state)
        end

        context 'without user' do
          it { expect(subject.call(address_params: address_params).success?).to eq(true) }
        end

        context 'user default address' do
          context 'when created address is first user address' do
            before { result }

            it 'assigns created address as default user bill address' do
              expect(user.reload.bill_address).to have_attributes(address_params)
            end

            it 'assigns created address as default user ship address' do
              expect(user.reload.ship_address).to have_attributes(address_params)
            end
          end

          context 'when user has some address already' do
            let!(:address) { create(:address, user: user) }

            context 'with default bill and ship address' do
              before do
                user.update(bill_address: address, ship_address: address)

                result
              end

              it 'does not assign created address as default user bill address' do
                expect(user.reload.bill_address).not_to have_attributes(address_params)
              end

              it 'does not assign created address as default user ship address' do
                expect(user.reload.ship_address).not_to have_attributes(address_params)
              end
            end

            context 'without default bill and ship address' do
              before { result }

              it 'does not assign created address as default user bill address' do
                expect(user.reload.bill_address).to be nil
              end

              it 'does not assign created address as default user ship address' do
                expect(user.reload.ship_address).to be nil
              end
            end
          end
        end

        context 'when order is passed' do
          let(:result) { subject.call(user: user, address_params: address_params, order: order) }

          let(:order) { create(:order, user: user, state: 'delivery', ship_address: address, bill_address: address) }
          let(:address) { create(:address, user: user) }

          it 'assigns a new ship address to the order' do
            result

            expect(order.reload.ship_address).to eq(value)
            expect(order.bill_address).to eq(address)
          end

          it 'updates order to address state' do
            expect { result }.to change { order.reload.state }.from('delivery').to('address')
          end
        end

        context 'when default billing is passed' do
          let(:result) { subject.call(user: user, address_params: address_params, default_billing: true) }

          let!(:user) { create(:user) }
          let!(:address) { create(:address, user: user) }

          before { user.update!(bill_address: address) }

          it 'updates user\'s bill address' do
            result
            expect(user.reload.bill_address).to eq(value)
          end
        end

        context 'when default shipping is passed' do
          let(:result) { subject.call(user: user, address_params: address_params, default_shipping: true) }

          let!(:user) { create(:user) }
          let!(:address) { create(:address, user: user) }

          before { user.update!(ship_address: address) }

          it 'updates user\'s ship address' do
            result
            expect(user.reload.ship_address).to eq(value)
          end
        end
      end

      context 'with invalid params' do
        let(:address_params) { {} }

        it 'returns errors' do
          expect { result }.not_to change(Address, :count)
          expect(result).to be_failure

          messages = result.error.value.messages
          expect(messages).to eq(
            address1: ["can't be blank"],
            city: ["can't be blank"],
            country: ["can't be blank"],
            firstname: ["can't be blank"],
            lastname: ["can't be blank"],
            zipcode: ["can't be blank"]
          )
        end
      end
    end
  end
end
