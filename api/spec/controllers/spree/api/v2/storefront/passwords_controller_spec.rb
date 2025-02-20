require 'spec_helper'

describe Spree::Api::V2::Storefront::PasswordsController, type: :controller do
  let!(:store) { create(:store) }
  let!(:user) { create(:user, store: store) }

  before do
    allow_any_instance_of(described_class).to receive(:current_store).and_return(store)
  end

  describe '#create' do
    subject { post :create, params: params }

    context 'with valid email' do
      let(:params) { { user: { email: user.email } } }

      it 'returns 200' do
        subject
        expect(response).to have_http_status(:ok)
      end

      it 'sends reset password instructions' do
        expect(user).to receive(:send_reset_password_instructions).with(store).and_return(true)
        allow(Spree.user_class).to receive(:find_by).with(email: user.email).and_return(user)
        subject
      end
    end

    context 'with invalid email' do
      let(:params) { { user: { email: 'invalid@example.com' } } }

      it 'returns 404' do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe '#update' do
    let(:new_password) { 'new_password123' }
    before { user.send_reset_password_instructions(store) }

    subject do
      put :update, params: {
        id: reset_password_token,
        user: {
          password: new_password,
          password_confirmation: password_confirmation
        }
      }
    end

    context 'with valid token and matching passwords' do
      let(:reset_password_token) { user.reset_password_token }
      let(:password_confirmation) { new_password }

      it 'returns 200' do
        subject
        expect(response).to have_http_status(:ok)
      end

      it 'changes user password' do
        subject
        expect(user.reload.valid_password?(new_password)).to be true
      end
    end

    context 'with invalid token' do
      let(:reset_password_token) { 'invalid_token' }
      let(:password_confirmation) { new_password }

      it 'returns 422' do
        subject
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error message' do
        subject
        expect(json_response['error']).to include('Reset password token is invalid')
      end
    end

    context 'with mismatched passwords' do
      let(:reset_password_token) { user.reset_password_token }
      let(:password_confirmation) { 'different_password' }

      it 'returns 422' do
        subject
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error message' do
        subject
        expect(json_response['error']).to include("Password confirmation doesn't match")
      end
    end

    context 'with invalid password' do
      let(:reset_password_token) { user.reset_password_token }
      let(:new_password) { '123' }
      let(:password_confirmation) { '123' }

      it 'returns 422' do
        subject
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error message' do
        subject
        expect(json_response['error']).to include('Password is too short')
      end
    end
  end
end
