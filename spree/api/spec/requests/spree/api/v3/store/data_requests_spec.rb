require 'spec_helper'

RSpec.describe 'Store data requests', type: :request do
  include_context 'API v3 Store'

  # A request reaches guest orders placed at the account's address only once
  # someone reading mail there confirms it.
  describe 'a request from an account whose address also has guest orders' do
    let(:guest_email) { 'guest@example.com' }
    let(:password) { 'Passw0rd!secret' }

    let!(:guest_order) do
      create(:completed_order_with_totals, store: store).tap do |order|
        order.update_columns(customer_id: nil, email: guest_email)
      end
    end

    let(:account_headers) do
      post '/api/v3/store/customers',
           params: { email: guest_email, password: password, password_confirmation: password },
           headers: api_key_headers, as: :json
      expect(response).to have_http_status(:created)

      api_key_headers.merge('Authorization' => "Bearer #{JSON.parse(response.body)['token']}")
    end

    def open_request(params)
      perform_enqueued_jobs do
        post '/api/v3/store/customers/me/data_requests', params: params, headers: account_headers, as: :json
      end
      expect(response).to have_http_status(:accepted)

      Spree::DataRequest.find_by_prefix_id!(JSON.parse(response.body)['id'])
    end

    it 'builds no export until the address confirms the request' do
      data_request = open_request(kind: 'access')

      expect(data_request.reload).to be_awaiting_confirmation
      expect(data_request.export_file).not_to be_attached
    end

    it 'leaves the guest order alone until the address confirms an erasure' do
      address1 = guest_order.ship_address.address1

      open_request(kind: 'erasure', current_password: password)

      guest_order.reload
      expect(guest_order.email).to eq(guest_email)
      expect(guest_order.ship_address.address1).to eq(address1)
    end

    it 'refuses the link once the account has moved to another address' do
      data_request = open_request(kind: 'access')
      token = data_request.generate_token_for(:confirmation)

      patch '/api/v3/store/customers/me',
            params: { email: 'another@example.com', current_password: password },
            headers: account_headers, as: :json
      expect(response).to have_http_status(:ok)

      post "/api/v3/store/data_requests/#{token}/confirmation", headers: api_key_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(data_request.reload).to be_lapsed
    end

    it 'hands the confirmed export to the token holder and never to the account' do
      data_request = open_request(kind: 'access')
      token = data_request.generate_token_for(:confirmation)

      perform_enqueued_jobs do
        post "/api/v3/store/data_requests/#{token}/confirmation", headers: api_key_headers, as: :json
      end
      expect(response).to have_http_status(:ok)

      get "/api/v3/store/customers/me/data_requests/#{data_request.prefixed_id}", headers: account_headers, as: :json
      expect(JSON.parse(response.body)['status']).to eq('completed')
      expect(JSON.parse(response.body)['download_url']).to be_nil

      get "/api/v3/store/data_requests/#{token}", headers: api_key_headers, as: :json
      download_url = JSON.parse(response.body)['download_url']

      get URI.parse(download_url).path
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['orders'].map { |order| order['number'] }).to include(guest_order.number)
    end
  end
end
