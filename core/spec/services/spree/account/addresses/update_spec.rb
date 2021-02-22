require 'spec_helper'

module Spree
  describe Account::Addresses::Update do
    subject { described_class }

    let(:user) { create(:user) }
    let(:country) { create(:country) }
    let(:state) { create(:state, country: country) }
    let!(:address) { create(:address, user: user) }
    let(:result) { subject.call(address: address, address_params: new_address_params) }
    let(:value) { result.value }

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

        it 'creates address' do
          expect { result }.not_to change(Address, :count)
          expect(result).to be_success
          expect(value).to have_attributes(new_address_params)
          expect(value.country).to eq(country)
          expect(value.state).to eq(state)
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
          expect { result }.not_to change(Address, :count)
          expect(result).to be_failure

          messages = result.error.value.messages
          expect(messages).to eq(
            phone: ["can't be blank"],
            zipcode: ["can't be blank"]
          )
        end
      end
    end
  end
end
