require 'rails_helper'

RSpec.describe 'Gift message', type: :request do
  let(:store) { @default_store }
  let(:api_key) { create(:api_key, :publishable, store: store) }
  let(:cart) { create(:cart_ready_to_complete, store: store) }
  let(:headers) { { 'x-spree-api-key' => api_key.token, 'x-spree-token' => cart.token } }

  it 'is set on the cart and kept on the placed order' do
    patch "/api/v3/store/carts/#{cart.prefixed_id}", params: { gift_message: 'Enjoy!' }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['gift_message']).to eq('Enjoy!')

    post "/api/v3/store/carts/#{cart.prefixed_id}/complete", headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['gift_message']).to eq('Enjoy!')
  end

  it 'rejects more than 500 characters' do
    patch "/api/v3/store/carts/#{cart.prefixed_id}", params: { gift_message: 'a' * 501 }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(cart.reload.gift_message).to be_nil
  end
end
