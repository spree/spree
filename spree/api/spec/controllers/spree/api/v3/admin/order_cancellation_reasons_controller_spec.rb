require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::OrderCancellationReasonsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:reason) { create(:order_cancellation_reason, name: 'Out of stock') }

  before { request.headers.merge!(headers) }

  it 'lists order cancellation reasons' do
    get :index, as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response['data'].map { |r| r['id'] }).to include(reason.prefixed_id)
  end

  it 'creates an order cancellation reason' do
    expect { post :create, params: { name: 'Duplicate order' }, as: :json }.
      to change(Spree::OrderCancellationReason, :count).by(1)

    expect(response).to have_http_status(:created)
  end

  it 'updates an order cancellation reason' do
    patch :update, params: { id: reason.prefixed_id, active: false }, as: :json

    expect(response).to have_http_status(:ok)
    expect(reason.reload.active).to be(false)
  end

  it 'refuses to delete a reason in use' do
    create(:order, cancel_reason: reason)

    expect { delete :destroy, params: { id: reason.prefixed_id }, as: :json }.
      not_to change(Spree::OrderCancellationReason, :count)
  end

  it 'does not expose another store\'s reasons' do
    other = create(:order_cancellation_reason, store: create(:store), name: 'Elsewhere')

    get :index, as: :json

    expect(json_response['data'].map { |r| r['id'] }).not_to include(other.prefixed_id)
  end

  # The dashboard authenticates with a JWT and no API key, so its abilities come
  # from the permission catalog rather than key scopes. A model missing from the
  # catalog's subject list reads as an empty list and refuses every write, while
  # the shared secret-key context above would still pass.
  context 'as staff authorized by permission keys alone' do
    include_context 'API v3 Admin with custom permissions'

    let(:custom_permissions) { %w[write_settings] }

    it 'lists the reasons' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |r| r['id'] }).to include(reason.prefixed_id)
    end

    it 'creates a reason' do
      expect { post :create, params: { name: 'Payment declined' }, as: :json }.
        to change(Spree::OrderCancellationReason, :count).by(1)

      expect(response).to have_http_status(:created)
    end
  end
end
