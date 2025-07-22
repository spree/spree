require 'spec_helper'

RSpec.describe Spree::Admin::ReimbursementTypesController, type: :controller do
  stub_authorization!
  render_views

  let(:reimbursement_type) { create(:reimbursement_type) }
  let(:valid_attributes) { { name: 'Test Type', active: true, mutable: true, type: 'Spree::ReimbursementType::Credit' } }
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
      it 'creates a new reimbursement type' do
        expect {
          post :create, params: { reimbursement_type: valid_attributes }
        }.to change(Spree::ReimbursementType, :count).by(1)

        reimbursement_type = Spree::ReimbursementType.last
        expect(reimbursement_type.name).to eq('Test Type')
        expect(reimbursement_type.active).to be true
        expect(reimbursement_type.mutable).to be true
        expect(reimbursement_type.type).to eq('Spree::ReimbursementType::Credit')
      end

      it 'redirects to the reimbursement types edit screen' do
        post :create, params: { reimbursement_type: valid_attributes }
        reimbursement_type = Spree::ReimbursementType.last
        expect(response).to redirect_to(edit_admin_reimbursement_type_path(reimbursement_type))
      end
    end

    context 'with invalid params' do
      it 'does not create a new reimbursement type' do
        expect {
          post :create, params: { reimbursement_type: invalid_attributes }
        }.not_to change(Spree::ReimbursementType, :count)
      end

      it 're-renders the new template' do
        post :create, params: { reimbursement_type: invalid_attributes }
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'GET #edit' do
    it 'returns a successful response' do
      get :edit, params: { id: reimbursement_type.to_param }
      expect(response).to be_successful
    end
  end

  describe 'PUT #update' do
    context 'with valid params' do
      let(:new_attributes) { { name: 'Updated Type', active: false, mutable: false, type: 'Spree::ReimbursementType::OriginalPayment' } }

      it 'updates the requested reimbursement type' do
        put :update, params: { id: reimbursement_type.to_param, reimbursement_type: new_attributes }
        reimbursement_type.reload
        expect(reimbursement_type.name).to eq('Updated Type')
        expect(reimbursement_type.active).to be false
        expect(reimbursement_type.mutable).to be false
        expect(reimbursement_type.type).to eq('Spree::ReimbursementType::OriginalPayment')
      end

      it 'redirects to the reimbursement type edit screen' do
        put :update, params: { id: reimbursement_type.to_param, reimbursement_type: new_attributes }
        expect(response).to redirect_to(edit_admin_reimbursement_type_path(reimbursement_type))
      end
    end

    context 'with invalid params' do
      it 'does not update the reimbursement type' do
        put :update, params: { id: reimbursement_type.to_param, reimbursement_type: invalid_attributes }
        expect(response).to render_template(:edit)
      end
    end
  end
end
