require 'spec_helper'

RSpec.describe Spree::Admin::RefundReasonsController, type: :controller do
  stub_authorization!
  render_views

  let(:refund_reason) { create(:refund_reason, mutable: true) }
  let(:valid_attributes) { { name: 'Test Reason', active: true, mutable: true } }
  let(:invalid_attributes) { { name: '', active: nil } }

  describe 'GET #index' do
    it 'returns a successful response' do
      get :index
      expect(response).to be_successful
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
      it 'creates a new refund reason' do
        expect {
          post :create, params: { refund_reason: valid_attributes }
        }.to change(Spree::RefundReason, :count).by(1)
      end

      it 'redirects to the refund reasons edit screen' do
        post :create, params: { refund_reason: valid_attributes }
        refund_reason = Spree::RefundReason.last
        expect(response).to redirect_to(edit_admin_refund_reason_path(refund_reason))
      end
    end

    context 'with invalid params' do
      it 'does not create a new refund reason' do
        expect {
          post :create, params: { refund_reason: invalid_attributes }
        }.not_to change(Spree::RefundReason, :count)
      end

      it 're-renders the new template' do
        post :create, params: { refund_reason: invalid_attributes }
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'GET #edit' do
    it 'returns a successful response' do
      get :edit, params: { id: refund_reason.to_param }
      expect(response).to be_successful
    end
  end

  describe 'PUT #update' do
    context 'with valid params' do
      let(:new_attributes) { { name: 'Updated Reason', active: false } }

      it 'updates the requested refund reason' do
        put :update, params: { id: refund_reason.to_param, refund_reason: new_attributes }
        refund_reason.reload
        expect(refund_reason.name).to eq('Updated Reason')
        expect(refund_reason.active).to be false
      end

      it 'redirects to the refund reason edit screen' do
        put :update, params: { id: refund_reason.to_param, refund_reason: new_attributes }
        expect(response).to redirect_to(edit_admin_refund_reason_path(refund_reason))
      end
    end

    context 'with invalid params' do
      it 'does not update the refund reason' do
        put :update, params: { id: refund_reason.to_param, refund_reason: invalid_attributes }
        expect(response).to render_template(:edit)
      end
    end
  end
end
