require 'spec_helper'

RSpec.describe Spree::Account::ProfileController, type: :controller do
  let(:store) { @default_store }
  let(:user) { create(:user, first_name: 'John', last_name: 'Doe', email: 'test@example.com', phone: '1234567890') }

  render_views

  before do
    allow(controller).to receive(:current_store).and_return(store)
    allow(controller).to receive(:try_spree_current_user).and_return(user)
  end

  describe 'GET #edit' do
    subject { get :edit }

    it 'renders the edit template' do
      subject
      expect(response).to render_template(:edit)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PUT #update' do
    subject { put :update, params: { user: user_params } }

    context 'with valid params' do
      let(:user_params) do
        { first_name: 'Jane', last_name: 'Smith', email: 'new@example.com', phone: '0987654321' }
      end

      it 'updates the user profile' do
        subject
        user.reload
        expect(user.first_name).to eq('Jane')
        expect(user.last_name).to eq('Smith')
        expect(user.email).to eq('new@example.com')
        expect(user.phone).to eq('0987654321')
        expect(response).to redirect_to(spree.edit_account_profile_path)
        expect(flash[:notice]).to eq('Account has been successfully updated!')
      end
    end

    context 'with invalid params' do
      let(:user_params) do
        { email: '' }
      end

      it 'renders the edit template with errors' do
        subject
        expect(response).to render_template(:edit)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
