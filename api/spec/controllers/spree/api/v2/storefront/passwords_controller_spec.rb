require 'spec_helper'

describe Spree::Api::V2::Storefront::PasswordsController, type: :controller do
  let(:user) { create(:user) }

  describe '#create' do
    subject { post :create, params: params }

    before do
      allow_any_instance_of(Spree.user_class).to receive(:send_reset_password_instructions).and_return(true)
    end

    context 'when everything goes ok' do
      let(:params) { { user: { email: user.email } } }

      it 'returns 200' do
        subject
        expect(response).to have_http_status(:ok)
      end

      it 'sends reset password instructions' do
        expect(user).to receive(:send_reset_password_instructions)
        allow(Spree.user_class).to receive(:find_by).with(email: user.email).and_return(user)
        subject
      end
    end

    context 'when there are errors' do
      let(:params) { { user: { email: 'invalid@example.com' } } }

      it 'returns 404' do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe '#update' do
    subject do
      put :update, params: {
        id: 'xxxxxx',
        user: {
          password: 'new_password',
          password_confirmation: 'new_password'
        }
      }
    end

    before do
      allow(Spree.user_class).to receive(:reset_password_by_token).and_return(user)
    end

    context 'when everything goes ok' do
      it 'returns 200' do
        subject
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when there are errors' do
      before do
        allow_any_instance_of(Spree.user_class).to receive(:errors).and_return(double(empty?: false, full_messages: ['Reset password token is invalid']))
      end

      it 'returns 422' do
        subject
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error message' do
        subject
        expect(json_response['error']).to include('Reset password token is invalid')
      end
    end
  end
end
