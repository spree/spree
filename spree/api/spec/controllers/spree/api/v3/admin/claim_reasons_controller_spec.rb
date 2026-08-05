require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::ClaimReasonsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:reason) { create(:claim_reason, name: 'Arrived damaged') }

  before { request.headers.merge!(headers) }

  it 'lists claim reasons' do
    get :index, as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response['data'].map { |r| r['id'] }).to include(reason.prefixed_id)
  end

  it 'creates a claim reason' do
    expect { post :create, params: { name: 'Never arrived' }, as: :json }.
      to change(Spree::ClaimReason, :count).by(1)

    expect(response).to have_http_status(:created)
  end

  it 'updates a claim reason' do
    patch :update, params: { id: reason.prefixed_id, active: false }, as: :json

    expect(response).to have_http_status(:ok)
    expect(reason.reload.active).to be(false)
  end

  it 'refuses to delete a reason in use' do
    create(:claim, reason: reason)

    expect { delete :destroy, params: { id: reason.prefixed_id }, as: :json }.
      not_to change(Spree::ClaimReason, :count)
  end
end
