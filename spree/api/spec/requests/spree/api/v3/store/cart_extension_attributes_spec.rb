require 'spec_helper'

RSpec.describe 'Store cart attributes added by extensions', type: :request do
  include_context 'API v3 Store guest'

  let(:cart) { create(:cart, store: store) }

  around do |example|
    original = Spree::Cart.additional_permitted_attributes
    example.run
    Spree::Cart.additional_permitted_attributes = original
  end

  it 'saves a column declared on the cart model when the cart is updated' do
    Spree::Cart.additional_permitted_attributes += [:accept_marketing]

    patch "/api/v3/store/carts/#{cart.prefixed_id}",
          params: { accept_marketing: true }, headers: headers.merge('x-spree-token' => cart.token), as: :json

    expect(response).to have_http_status(:ok)
    expect(cart.reload.accept_marketing).to be(true)
  end

  it 'ignores the column while no extension declares it' do
    patch "/api/v3/store/carts/#{cart.prefixed_id}",
          params: { accept_marketing: true }, headers: headers.merge('x-spree-token' => cart.token), as: :json

    expect(response).to have_http_status(:ok)
    expect(cart.reload.accept_marketing).to be(false)
  end
end
