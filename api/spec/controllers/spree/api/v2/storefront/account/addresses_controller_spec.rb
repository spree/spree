require 'spec_helper'

describe 'Spree::Api::V2::Storefront::Account::AddressesController', type: :request do
  let!(:user) { create(:user_with_addresses) }
  let!(:addresses) { create_list(:address, 1, user_id: user.id, country: country, state: state) }
  let!(:country) { create(:country) }
  let!(:state) { create(:state, country: country) }
  let(:params) { { address: new_attributes } }

  include_context 'API v2 tokens'

  describe 'addresses#create' do
    subject :post_create do
      post '/api/v2/storefront/account/addresses', params: params, headers: headers_bearer
    end

    context 'valid request' do
      let(:new_attributes) do
        {
          firstname: 'John',
          lastname: 'Doe',
          address1: '51 Guild Street',
          address2: '2nd floor',
          city: 'London',
          phone: '079 4721 9458',
          zipcode: 'SE25 3FZ',
          state_name: 'England',
          country_id: country.id
        }
      end

      it 'returns created address attributes' do
        post_create

        expect(json_response['data']).to have_attribute(:firstname).with_value(new_attributes[:firstname])
        expect(json_response['data']).to have_attribute(:lastname).with_value(new_attributes[:lastname])
        expect(json_response['data']).to have_attribute(:address1).with_value(new_attributes[:address1])
        expect(json_response['data']).to have_attribute(:address2).with_value(new_attributes[:address2])
        expect(json_response['data']).to have_attribute(:city).with_value(new_attributes[:city])
        expect(json_response['data']).to have_attribute(:phone).with_value(new_attributes[:phone])
        expect(json_response['data']).to have_attribute(:zipcode).with_value(new_attributes[:zipcode])
        expect(json_response['data']).to have_attribute(:state_name).with_value(new_attributes[:state_name])
        expect(json_response.size).to eq(1)
      end

      it 'creates address' do
        expect{ post_create }.to change { Spree::Address.count }.by(1)
      end
    end

    context 'invalid request' do
      let(:new_attributes) do
        {
          firstname: 'John',
          lastname: 'Doe',
          address1: '51 Guild Street',
          address2: '2nd floor'
        }
      end

      it 'returns errors' do
        post_create

        expect(json_response['error']).to eq("City can't be blank, Country can't be blank, Zip Code can't be blank, Phone can't be blank")
        expect(json_response['errors']).to eq(
                                             'city' => ["can't be blank"],
                                             'zipcode' => ["can't be blank"],
                                             'country' => ["can't be blank"],
                                             'phone' => ["can't be blank"]
                                           )
      end

      it 'does not create address' do
        expect{ post_create }.to change { Spree::Address.count }.by(0)
      end
    end

    context 'with missing authorization token' do
      before { post '/api/v2/storefront/account/addresses' }

      it_behaves_like 'returns 403 HTTP status'
    end
  end

  describe 'addresses#update' do
    subject :patch_update do
      patch "/api/v2/storefront/account/addresses/#{address.id}", params: params, headers: headers_bearer
    end

    let(:address) { addresses.last }

    context 'when address is editable' do
      context 'valid request' do
        let(:new_attributes) do
          {
            firstname: 'John',
            lastname: 'Doe',
            address1: '51 Guild Street',
            address2: '2nd floor',
            city: 'London',
            phone: '079 4721 9458',
            zipcode: 'SE25 3FZ',
            state_name: state.name,
          }
        end

        it 'updates and returns address' do
          patch_update

          expect(json_response['data']).to have_id(address.id.to_s)
          expect(json_response['data']).to have_attribute(:firstname).with_value(new_attributes[:firstname])
          expect(json_response['data']).to have_attribute(:lastname).with_value(new_attributes[:lastname])
          expect(json_response['data']).to have_attribute(:address1).with_value(new_attributes[:address1])
          expect(json_response['data']).to have_attribute(:address2).with_value(new_attributes[:address2])
          expect(json_response['data']).to have_attribute(:city).with_value(new_attributes[:city])
          expect(json_response['data']).to have_attribute(:phone).with_value(new_attributes[:phone])
          expect(json_response['data']).to have_attribute(:zipcode).with_value(new_attributes[:zipcode])
          expect(json_response['data']).to have_attribute(:state_name).with_value(new_attributes[:state_name])
          expect(json_response.size).to eq(1)
        end

        it 'does not create new address' do
          expect{ patch_update }.to change { Spree::Address.count }.by(0)
        end
      end

      context 'invalid request' do
        let(:new_attributes) do
          {
            firstname: '',
            lastname: 'Doe',
            address1: '51 Guild Street',
            address2: '2nd floor',
            city: 'London',
            phone: '079 4721 9458',
            zipcode: 'SE25 3FZ',
            state_name: state.name,
          }
        end

        it 'returns errors' do
          patch_update

          expect(json_response['error']).to eq("First Name can't be blank")
          expect(json_response['errors']).to eq(
                                               'firstname' => ["can't be blank"]
                                             )
        end

        it 'does not update address' do
          expect { patch_update }.not_to change { address }
        end
      end
    end

    context 'when address is not editable' do
      let!(:shipment) { create(:shipment, address: address) }

      context 'valid request' do
        let(:new_attributes) do
          {
            firstname: 'John',
            lastname: 'Doe',
            address1: '51 Guild Street',
            address2: '2nd floor',
            city: 'London',
            phone: '079 4721 9458',
            zipcode: 'SE25 3FZ',
            state_name: state.name,
          }
        end

        it 'returns created address attributes' do
          patch_update

          expect(json_response['data']).to have_attribute(:firstname).with_value(new_attributes[:firstname])
          expect(json_response['data']).to have_attribute(:lastname).with_value(new_attributes[:lastname])
          expect(json_response['data']).to have_attribute(:address1).with_value(new_attributes[:address1])
          expect(json_response['data']).to have_attribute(:address2).with_value(new_attributes[:address2])
          expect(json_response['data']).to have_attribute(:city).with_value(new_attributes[:city])
          expect(json_response['data']).to have_attribute(:phone).with_value(new_attributes[:phone])
          expect(json_response['data']).to have_attribute(:zipcode).with_value(new_attributes[:zipcode])
          expect(json_response['data']).to have_attribute(:state_name).with_value(new_attributes[:state_name])
          expect(json_response.size).to eq(1)
        end

        it 'creates address' do
          expect{ patch_update }.to change { Spree::Address.count }.by(1)
        end

        it 'sets deleted_at attribute of original address' do
          Timecop.freeze(Time.current) do
            expect(address.deleted_at).to be_nil

            patch_update

            expect(address.reload.deleted_at).not_to be nil
          end
        end
      end

      context 'invalid request' do
        let(:new_attributes) do
          {
            firstname: '',
            lastname: 'Doe',
            address1: '51 Guild Street',
            address2: '2nd floor',
            city: 'London',
            phone: '079 4721 9458',
            zipcode: 'SE25 3FZ',
            state_name: state.name,
          }
        end

        it 'returns errors' do
          patch_update

          expect(json_response['error']).to eq("First Name can't be blank")
          expect(json_response['errors']).to eq(
                                               'firstname' => ["can't be blank"]
                                             )
        end

        it 'does not update address' do
          expect { patch_update }.not_to change { address }
        end
      end
    end

    context 'with missing authorization token' do
      before { patch "/api/v2/storefront/account/addresses/#{address.id}" }

      it_behaves_like 'returns 403 HTTP status'
    end
  end
end
