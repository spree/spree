require 'spec_helper'

# TODO: this spec needs to be rewritten as it name clashes with the admin users spec
xdescribe 'Platform API v2 Users API' do
  include_context 'Platform API v2'

  let(:bearer_token) { { 'Authorization' => valid_authorization } }

  describe 'users#index' do
    let!(:user) { create(:user, email: 'john@snow.org') }
    let!(:user_2) { create(:user, email: 'daenyerys@targaryen.org') }

    context 'filtering' do
      context 'by email' do
        before { get '/api/v2/platform/users?filter[email_eq]=john@snow.org', headers: bearer_token }

        it 'returns users with matching email' do
          expect(json_response['data'].count).to eq 1
          expect(json_response['data'].first).to have_id(user.id.to_s)
        end
      end

      context 'by address firstname' do
        let!(:address) { create(:address, firstname: 'Daenerys', user: user_2) }

        before { get '/api/v2/platform/users?filter[addresses_firstname_eq]=Daenerys', headers: bearer_token }

        it 'returns users with matching address firstname' do
          expect(json_response['data'].count).to eq 1
          expect(json_response['data'].first).to have_id(user_2.id.to_s)
        end
      end

      context 'by address lastname' do
        let!(:address) { create(:address, lastname: 'Targaryen', user: user_2) }

        before { get '/api/v2/platform/users?filter[addresses_lastname_eq]=Targaryen', headers: bearer_token }

        it 'returns users with matching address lastname' do
          expect(json_response['data'].count).to eq 1
          expect(json_response['data'].first).to have_id(user_2.id.to_s)
        end
      end

      context 'by address firstname, lastname and email combined' do
        let!(:address) { create(:address, firstname: 'John', user: user) }
        let!(:address_2) { create(:address, lastname: 'Targaryen', user: user_2) }

        before do
          get '/api/v2/platform/users?filter[m]=or&filter[addresses_lastname_eq]=targaryen&filter[addresses_firstname_eq]=John', headers: bearer_token
        end

        it 'returns users with matching address lastname' do
          expect(json_response['data'].count).to eq 2
        end
      end
    end
  end
end
