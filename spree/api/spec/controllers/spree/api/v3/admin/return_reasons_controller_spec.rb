require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::ReturnReasonsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:reason) { create(:return_reason, name: 'Wrong size') }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns return reasons' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |r| r['id'] }).to include(reason.prefixed_id)
    end

    it 'filters by active' do
      inactive = create(:return_reason, name: 'Retired reason', active: false)

      get :index, params: { q: { active_eq: false } }, as: :json

      ids = json_response['data'].map { |r| r['id'] }
      expect(ids).to include(inactive.prefixed_id)
      expect(ids).not_to include(reason.prefixed_id)
    end
  end

  describe 'GET #show' do
    it 'returns the reason' do
      get :show, params: { id: reason.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('Wrong size')
      expect(json_response['can_be_deleted']).to be(true)
    end
  end

  describe 'POST #create' do
    it 'creates a reason' do
      expect { post :create, params: { name: 'Changed my mind', active: true }, as: :json }.
        to change(Spree::ReturnReason, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('Changed my mind')
    end

    it 'rejects a blank name' do
      post :create, params: { name: '' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects a duplicate name' do
      post :create, params: { name: reason.name }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #update' do
    it 'updates the reason' do
      patch :update, params: { id: reason.prefixed_id, name: 'Too small' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(reason.reload.name).to eq('Too small')
    end

    it 'does not allow unlocking a protected reason' do
      locked = create(:return_reason, name: 'Locked', mutable: false)

      patch :update, params: { id: locked.prefixed_id, mutable: true }, as: :json

      expect(locked.reload.mutable).to be(false)
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes the reason' do
      expect { delete :destroy, params: { id: reason.prefixed_id }, as: :json }.
        to change(Spree::ReturnReason, :count).by(-1)
    end

    it 'refuses to delete a reason in use' do
      return_record = create(:return, reason: reason)

      expect { delete :destroy, params: { id: reason.prefixed_id }, as: :json }.
        not_to change(Spree::ReturnReason, :count)

      expect(return_record.reload.reason).to eq(reason)
    end

    it 'refuses to delete a protected reason' do
      locked = create(:return_reason, name: 'Locked', mutable: false)

      expect { delete :destroy, params: { id: locked.prefixed_id }, as: :json }.
        not_to change(Spree::ReturnReason, :count)
    end
  end
end
