require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::RefundReasonsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:reason) { create(:refund_reason, name: 'Goodwill gesture') }

  before { request.headers.merge!(headers) }

  it 'lists refund reasons' do
    get :index, as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response['data'].map { |r| r['id'] }).to include(reason.prefixed_id)
  end

  it 'creates a refund reason' do
    expect { post :create, params: { name: 'Price match' }, as: :json }.
      to change(Spree::RefundReason, :count).by(1)
  end

  # The seeded reasons are per store now, so one store's "Return processing"
  # is invisible to another rather than shared.
  describe 'store scoping' do
    let!(:other_store) { create(:store) }
    let!(:other_store_reason) { Spree::RefundReason.return_processing_reason(other_store) }

    it 'excludes another store\'s reason from the listing' do
      get :index, as: :json

      expect(json_response['data'].map { |r| r['id'] }).not_to include(other_store_reason.prefixed_id)
    end

    it 'gives each store its own seeded reason' do
      mine = Spree::RefundReason.return_processing_reason(@default_store)

      expect(mine.id).not_to eq(other_store_reason.id)
      expect(mine.name).to eq(other_store_reason.name)
    end
  end

  # Core looks this one up by name to attach to every return refund.
  context 'with the seeded return-processing reason' do
    let!(:locked) { Spree::RefundReason.return_processing_reason }

    it 'reports that it cannot be deleted' do
      get :show, params: { id: locked.prefixed_id }, as: :json

      expect(json_response['can_be_deleted']).to be(false)
    end

    # The ability layer denies :update on an immutable reason outright, and
    # the v3 error handler renders that as 404 rather than leaking existence.
    # The model guard below it is what protects the secret-key path, which
    # authorizes by scope and never consults CanCanCan.
    it 'refuses to rename it' do
      patch :update, params: { id: locked.prefixed_id, name: 'Something else' }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(locked.reload.name).to eq(Spree::RefundReason::RETURN_PROCESSING_REASON)
    end

    it 'refuses to delete it' do
      expect { delete :destroy, params: { id: locked.prefixed_id }, as: :json }.
        not_to change(Spree::RefundReason, :count)
    end
  end
end
