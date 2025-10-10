require 'spec_helper'

RSpec.describe Spree::Admin::ReturnAuthorizationReasonsController, type: :controller do
  stub_authorization!
  render_views

  let(:return_authorization_reason) { create(:return_authorization_reason) }
  let(:valid_attributes) { { name: 'Test Reason', active: true } }
  let(:invalid_attributes) { { name: '', active: nil } }

  describe 'GET #index' do
    it 'returns a successful response' do
      get :index
      expect(response).to be_successful
    end

    context 'with existing return authorization reasons' do
      let!(:return_authorization_reason) { create(:return_authorization_reason) }
      let!(:return_authorization_reason_2) { create(:return_authorization_reason, name: 'B') }

      it 'returns a successful response' do
        get :index
        expect(response).to be_successful
      end

      it 'orders the return authorization reasons by name' do
        get :index
        expect(assigns(:return_authorization_reasons)).to eq([return_authorization_reason_2, return_authorization_reason])
      end
    end
  end

  describe 'GET #new' do
    it 'returns a successful response' do
      get :new
      expect(response).to be_successful
    end
  end

  describe 'POST #create' do
    context 'with valid params' do
      it 'creates a new return authorization reason' do
        expect {
          post :create, params: { return_authorization_reason: valid_attributes }
        }.to change(Spree::ReturnAuthorizationReason, :count).by(1)
      end

      it 'redirects to the return authorization reasons edit screen' do
        post :create, params: { return_authorization_reason: valid_attributes }
        return_authorization_reason = Spree::ReturnAuthorizationReason.last
        expect(response).to redirect_to(edit_admin_return_authorization_reason_path(return_authorization_reason))
      end
    end

    context 'with invalid params' do
      it 'does not create a new return authorization reason' do
        expect {
          post :create, params: { return_authorization_reason: invalid_attributes }
        }.not_to change(Spree::ReturnAuthorizationReason, :count)
      end

      it 're-renders the new template' do
        post :create, params: { return_authorization_reason: invalid_attributes }
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'GET #edit' do
    it 'returns a successful response' do
      get :edit, params: { id: return_authorization_reason.to_param }
      expect(response).to be_successful
    end
  end

  describe 'PUT #update' do
    context 'with valid params' do
      let(:new_attributes) { { name: 'Updated Reason', active: false } }

      it 'updates the requested return authorization reason' do
        put :update, params: { id: return_authorization_reason.to_param, return_authorization_reason: new_attributes }
        return_authorization_reason.reload
        expect(return_authorization_reason.name).to eq('Updated Reason')
        expect(return_authorization_reason.active).to be false
      end

      it 'redirects to the return authorization reason edit screen' do
        put :update, params: { id: return_authorization_reason.to_param, return_authorization_reason: new_attributes }
        expect(response).to redirect_to(edit_admin_return_authorization_reason_path(return_authorization_reason))
      end
    end

    context 'with invalid params' do
      it 'does not update the return authorization reason' do
        put :update, params: { id: return_authorization_reason.to_param, return_authorization_reason: invalid_attributes }
        expect(response).to render_template(:edit)
      end
    end
  end
end
