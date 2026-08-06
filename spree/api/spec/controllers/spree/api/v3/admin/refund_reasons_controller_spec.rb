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

  context 'with a reason that is already used by a refund' do
    let!(:in_use) { create(:refund, reason: reason, amount: 1).reason }

    it 'reports that it cannot be deleted' do
      get :show, params: { id: in_use.prefixed_id }, as: :json

      expect(json_response['can_be_deleted']).to be(false)
    end

    it 'refuses to delete it' do
      expect { delete :destroy, params: { id: in_use.prefixed_id }, as: :json }.
        not_to change(Spree::RefundReason, :count)
    end

    it 'still allows renaming it' do
      patch :update, params: { id: in_use.prefixed_id, name: 'Something else' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(in_use.reload.name).to eq('Something else')
    end
  end
end
