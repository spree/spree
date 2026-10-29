require 'spec_helper'

# A key selects its store, so once the store is deleted the key must be
# refused, not authenticate a request that then runs with no store.
# Deliberately no shared API context: those stub the current store, which is
# exactly what this needs to resolve for real.
RSpec.describe 'API keys of a deleted store', type: :request do
  let(:store) { create(:store) }

  def soft_delete(store)
    store.update_columns(deleted_at: Time.current)
  end

  it 'refuses a publishable key on the Store API' do
    headers = { 'X-Spree-Api-Key' => create(:api_key, :publishable, store: store).token }
    get '/api/v3/store/products', headers: headers
    expect(response).to have_http_status(:ok)

    soft_delete(store)
    get '/api/v3/store/products', headers: headers

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body).dig('error', 'code')).to eq('invalid_token')
  end

  it 'refuses a secret key on the Admin API' do
    headers = { 'X-Spree-Api-Key' => create(:api_key, :secret, store: store).plaintext_token }
    get '/api/v3/admin/products', headers: headers
    expect(response).to have_http_status(:ok)

    soft_delete(store)
    get '/api/v3/admin/products', headers: headers

    expect(response).to have_http_status(:unauthorized)
  end
end
