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
            phone: ["can't be blank"],
            zipcode: ["can't be blank"]
          )
        end
      end
    end
  end
end
