require 'spec_helper'

describe 'Platform API v2 Resources spec', type: :request do
  include_context 'API v2 tokens'
  include_context 'Platform API v2'

  let(:bearer_token) { { 'Authorization' => valid_authorization } }
  let(:resource_params) { {} }
  let(:params) { { address: resource_params } }
  let(:country) { create(:country, states_required: true) }
  let(:state) { create(:state, country: country) }
  let(:user) { create(:user) }
  let(:resource) { create(:address, state: state, country: country, user: user) }
  let(:id) { resource.id }
  let(:valid_http_status) { 200 }

  shared_examples 'returns auth token errors' do
    context 'with missing authorization token' do
      let(:bearer_token) { nil }

      before { execute }

      it_behaves_like 'returns 401 HTTP status'
    end

    context 'with wrong authorization token' do
      let(:bearer_token) { { 'Authorization' => bogus_authorization } }

      before { execute }

      it_behaves_like 'returns 401 HTTP status'
    end
  end

  shared_examples 'returns error when record does not exist' do
    let(:id) { 'bogus' }

    before { execute }

    it_behaves_like 'returns 404 HTTP status'
  end

  describe '#index' do
    let(:params) { }
    let(:execute) { get '/api/v2/platform/addresses', headers: bearer_token, params: params }
    let!(:resources) { create_list(:address, 5) }
    let(:resources_count) { 5 }

    shared_examples 'valid request' do
      before { execute }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns valid JSON' do
        expect(json_response['data'][0]).to have_type(resource.class.json_api_type)
        expect(json_response['data'].count).to eq(resources_count)
      end
    end

    context 'application with access token' do
      it_behaves_like 'valid request'

      context 'ransack filtering' do
        let(:ids) { resources.last(2).map(&:id) }

        context 'single filter' do
          let(:params) { { filter: { 'id_in': ids } } }

          before { execute }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns proper resources' do
            expect(json_response['data'][0]).to have_type(resource.class.json_api_type)
            expect(json_response['data'].count).to eq(2)
            expect(json_response['data'].first).to have_id(ids.first.to_s)
            expect(json_response['data'].last).to have_id(ids.last.to_s)
          end
        end

        context 'multiple filters' do
          let(:params) { { filter: { 'id_in': ids, firstname_cont: 'Joan' } } }

          before do
            resources.last.update(firstname: 'Joanna')
            execute
          end

          it_behaves_like 'returns 200 HTTP status'

          it 'returns proper resources' do
            expect(json_response['data'][0]).to have_type(resource.class.json_api_type)
            expect(json_response['data'].count).to eq(1)
            expect(json_response['data'].first).to have_id(ids.last.to_s)
          end
        end
      end

      context 'pagination' do
        context 'when per_page is between 1 and default value' do
          let(:params) { { page: 1, per_page: 2 } }

          before { execute }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns proper resource count' do
            expect(json_response['data'].count).to eq 2
          end

          it 'returns proper meta data' do
            expect(json_response['meta']['count']).to       eq 2
            expect(json_response['meta']['total_count']).to eq resources.count
          end

          it 'returns proper links data' do
            expect(json_response['links']['self']).to include('/api/v2/platform/addresses?page=1&per_page=2')
            expect(json_response['links']['next']).to include('/api/v2/platform/addresses?page=2&per_page=2')
            expect(json_response['links']['prev']).to include('/api/v2/platform/addresses?page=1&per_page=2')
          end
        end

        context 'when per_page is above the default value' do
          let(:params) { { page: 1, per_page: 10 } }

          before { execute }

          it 'returns the proper resource count' do
            expect(json_response['data'].count).to eq resources.count
          end
        end

        context 'when per_page is less than 0' do
          let(:params) { { page: 1, per_page: '-1' } }

          before { execute }

          it 'returns the proper resource count' do
            expect(json_response['data'].count).to eq resources.count
          end
        end

        context 'when per_page is equal 0' do
          let(:params) { { page: 1, per_page: 0 } }

          before { execute }

          it 'returns the proper resource count' do
            expect(json_response['data'].count).to eq resources.count
          end
        end
      end

      context 'without specified pagination params' do
        before { execute }

        it_behaves_like 'returns 200 HTTP status'

        it 'returns specified amount resources' do
          expect(json_response['data'].count).to eq resources.count
        end

        it 'returns proper meta data' do
          expect(json_response['meta']['count']).to       eq json_response['data'].count
          expect(json_response['meta']['total_count']).to eq resources.count
        end

        it 'returns proper links data' do
          expect(json_response['links']['self']).to include('/api/v2/platform/addresses')
          expect(json_response['links']['next']).to include('/api/v2/platform/addresses?page=1')
          expect(json_response['links']['prev']).to include('/api/v2/platform/addresses?page=1')
        end
      end
    end

    context 'user with access token' do
      let(:bearer_token) { { 'Authorization' => valid_user_authorization } }

      before do
        resources.first(3).each { |r| r.update(user: user) }
        execute
      end

      context 'regular user' do
        let(:resources_count) { 3 }

        it_behaves_like 'valid request'
      end

      context 'admin user' do
        let(:user) { create(:admin_user) }
        let(:resources_count) { 5 }

        it_behaves_like 'valid request'
      end
    end

    it_behaves_like 'returns auth token errors'
  end

  describe '#show' do
    let(:execute) { get "/api/v2/platform/addresses/#{id}", headers: bearer_token }

    shared_examples 'valid request' do
      before { execute }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns valid JSON' do
        expect(json_response['data']).to have_attribute(:firstname).with_value(resource.firstname)
        expect(json_response['data']).to have_attribute(:lastname).with_value(resource.lastname)
        expect(json_response['data']).to have_relationships(:state, :country, :user)
      end
    end

    context 'application with access token' do
      it_behaves_like 'valid request'
    end

    context 'user with access token' do
      let(:bearer_token) { { 'Authorization' => valid_user_authorization } }

      context 'user with access' do
        it_behaves_like 'valid request'
      end

      context 'user without access' do
        let(:another_user) { create(:user) }

        before do
          resource.update!(user: another_user)
          execute
        end

        it_behaves_like 'returns 404 HTTP status'
      end

      context 'admin user' do
        let(:user) { create(:admin_user) }

        it_behaves_like 'valid request'
      end
    end

    it_behaves_like 'returns auth token errors'
    it_behaves_like 'returns error when record does not exist'
  end

  describe '#create' do
    let(:execute) { post '/api/v2/platform/addresses', params: params, headers: bearer_token }
    let(:resource_params) { build(:address, country: country, state: state, user: user).attributes.symbolize_keys }

    shared_examples 'valid request' do
      before { execute }

      it 'creates and returns resource' do
        expect(json_response['data']).to have_attribute(:firstname).with_value(resource_params[:firstname])
        expect(json_response['data']).to have_attribute(:lastname).with_value(resource_params[:lastname])
        expect(json_response['data']).to have_attribute(:address1).with_value(resource_params[:address1])
        expect(json_response['data']).to have_attribute(:address2).with_value(resource_params[:address2])
        expect(json_response['data']).to have_attribute(:city).with_value(resource_params[:city])
        expect(json_response['data']).to have_attribute(:phone).with_value(resource_params[:phone])
        expect(json_response['data']).to have_attribute(:zipcode).with_value(resource_params[:zipcode])
        expect(json_response['data']).to have_relationship(:state).with_data({ 'id' => state.id.to_s, 'type' => 'state' })
        expect(json_response['data']).to have_relationship(:country).with_data({ 'id' => country.id.to_s, 'type' => 'country' })
        expect(json_response['data']).to have_relationship(:user).with_data({ 'id' => user.id.to_s, 'type' => 'user' })
      end

      it_behaves_like 'returns 201 HTTP status'
    end

    context 'application with admin access token' do
      it_behaves_like 'valid request'
    end

    context 'application with read access token' do
      let(:bearer_token) { { 'Authorization' => valid_read_authorization } }

      before { execute }

      it_behaves_like 'returns 401 HTTP status'
    end

    context 'user with access token' do
      let(:bearer_token) { { 'Authorization' => valid_user_authorization } }

      it_behaves_like 'valid request'
    end

    context 'invalid request' do
      let(:resource_params) do
        {
          firstname: 'John',
          lastname: 'Doe',
          address1: '51 Guild Street',
          address2: '2nd floor'
        }
      end

      before { execute }

      it 'returns errors' do
        expect(json_response['error']).to eq("City can't be blank, Country can't be blank, Zip Code can't be blank, and Phone can't be blank")
        expect(json_response['errors']).to eq(
          'city' => ["can't be blank"],
          'zipcode' => ["can't be blank"],
          'country' => ["can't be blank"],
          'phone' => ["can't be blank"]
        )
      end
    end

    it_behaves_like 'returns auth token errors'
  end

  describe '#update' do
    let(:execute) { put "/api/v2/platform/addresses/#{id}", params: params, headers: bearer_token }

    shared_examples 'valid request' do
      let(:resource_params) do
        {
          firstname: 'John',
          lastname: 'Doe',
          address1: '51 Guild Street',
          address2: '2nd floor',
          city: 'London',
          phone: '079 4721 9458',
          zipcode: 'SE25 3FZ',
          state_id: another_state.id
        }
      end

      let(:another_state) { create(:state, country: country) }

      before { execute }

      it 'updates and returns resource' do
        expect(json_response['data']).to have_id(resource.id.to_s)
        expect(json_response['data']).to have_attribute(:firstname).with_value(resource_params[:firstname])
        expect(json_response['data']).to have_attribute(:lastname).with_value(resource_params[:lastname])
        expect(json_response['data']).to have_attribute(:address1).with_value(resource_params[:address1])
        expect(json_response['data']).to have_attribute(:address2).with_value(resource_params[:address2])
        expect(json_response['data']).to have_attribute(:city).with_value(resource_params[:city])
        expect(json_response['data']).to have_attribute(:phone).with_value(resource_params[:phone])
        expect(json_response['data']).to have_attribute(:zipcode).with_value(resource_params[:zipcode])

        expect(json_response['data']).to have_relationship(:state).with_data({ 'id' => another_state.id.to_s, 'type' => 'state' })
      end

      it_behaves_like 'returns 200 HTTP status'
    end

    context 'application with full access token' do
      it_behaves_like 'valid request'
    end

    context 'application with read access token' do
      let(:bearer_token) { { 'Authorization' => valid_read_authorization } }
      let(:resource_params) do
        {
          firstname: 'John',
          lastname: 'Doe'
        }
      end

      before { execute }

      it_behaves_like 'returns 401 HTTP status'
    end

    context 'user with access token' do
      let(:bearer_token) { { 'Authorization' => valid_user_authorization } }

      it_behaves_like 'valid request'
    end

    context 'user without access' do
      let(:another_user) { create(:user) }
      let(:bearer_token) { { 'Authorization' => valid_user_authorization } }
      let(:resource_params) do
        {
          firstname: 'John',
          lastname: 'Doe'
        }
      end

      before do
        resource.update!(user: another_user)
        execute
      end

      it_behaves_like 'returns 404 HTTP status'
    end

    context 'invalid request' do
      let(:resource_params) do
        {
          city: '',
          zipcode: ''
        }
      end

      before { execute }

      it 'returns errors' do
        expect(json_response['error']).to eq("City can't be blank and Zip Code can't be blank")
        expect(json_response['errors']).to eq(
          'city' => ["can't be blank"],
          'zipcode' => ["can't be blank"]
        )
      end
    end

    it_behaves_like 'returns auth token errors'
    it_behaves_like 'returns error when record does not exist'
  end

  context '#destroy' do
    let(:execute) { delete "/api/v2/platform/addresses/#{id}", headers: bearer_token }

    context 'deletes record' do
      before { execute }

      it_behaves_like 'returns 204 HTTP status'

      it 'returns with empty response' do
        expect(response.body).to be_empty
      end
    end

    context 'application with read access token' do
      let(:bearer_token) { { 'Authorization' => valid_read_authorization } }

      before { execute }

      it_behaves_like 'returns 401 HTTP status'
    end

    it_behaves_like 'returns auth token errors'
    it_behaves_like 'returns error when record does not exist'
  end
end
