import { runAcceptanceSpec } from '../lib/project.mjs'

const SPEC = `require 'rails_helper'

RSpec.describe 'Agent benchmark: gift message', type: :request do
  let(:store) { @default_store }
  let(:api_key) { create(:api_key, :publishable, store: store) }
  let(:cart) { create(:cart, store: store) }
  let(:headers) { { 'x-spree-api-key' => api_key.token, 'x-spree-token' => cart.token } }

  it 'stores the gift message on orders' do
    expect(Spree::Order.new).to respond_to(:gift_message)
  end

  it 'sets and returns the gift message on the cart through the Store API' do
    patch "/api/v3/store/carts/#{cart.prefixed_id}", params: { gift_message: 'Happy birthday!' }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['gift_message']).to eq('Happy birthday!')

    get "/api/v3/store/carts/#{cart.prefixed_id}", headers: headers, as: :json
    expect(JSON.parse(response.body)['gift_message']).to eq('Happy birthday!')
  end

  it 'rejects a gift message longer than 500 characters' do
    patch "/api/v3/store/carts/#{cart.prefixed_id}", params: { gift_message: 'a' * 501 }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_content)
  end
end
`

export default {
  id: 'order-gift-message',
  title: 'Add a gift message to orders in the Store API',
  project: { storefront: false },
  timeoutMinutes: 30,
  prompt: `Shoppers want to add a gift message to their order.

Add a gift_message to orders: plain text, optional, at most 500 characters. Our storefront must be able to set it on the cart through the Store API, read it back from the cart, and the message must stay on the order once it is placed. A message that is too long should be rejected with a validation error.

Add specs, and make sure the change is live in the running app.`,
  check: ({ projectDir }) => runAcceptanceSpec(projectDir, 'gift_message', SPEC),
}
