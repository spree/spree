require 'spec_helper'

describe Spree::Api::V2::Storefront::AccountConfirmationsController, type: :controller do
  describe '#show' do
    subject { get :show, params: { id: confirmation_token } }

    context 'when everything goes ok' do
      let(:user) { create(:user) }
      let(:confirmation_token) { 'valid_token' }

      before do
        allow(Spree.user_class).to receive(:confirm_by_token).with(confirmation_token).and_return(user)
      end

      it 'returns 200' do
        subject
        expect(response).to have_http_status(:ok)
      end

      it 'returns user state' do
        allow(user).to receive(:state).and_return('confirmed')
        subject
        expect(json_response['data']['state']).to eq('confirmed')
      end

      context 'when user does not respond to state' do
        before do
          allow(user).to receive(:respond_to?).with(:state).and_return(false)
        end

        it 'returns empty state' do
          subject
          expect(json_response['data']['state']).to eq('')
        end
      end
    end

    context 'when there are errors' do
      let(:user) { create(:user) }
      let(:confirmation_token) { 'invalid_token' }
      let(:error_messages) { ['Confirmation token is invalid'] }

      before do
        allow(Spree.user_class).to receive(:confirm_by_token).with(confirmation_token).and_return(user)
        allow(user).to receive(:errors).and_return(
          double(empty?: false, full_messages: error_messages)
        )
      end

      it 'returns 422' do
        subject
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error message' do
        subject
        expect(json_response['error']).to eq(error_messages.to_sentence)
      end
    end
  end
end
