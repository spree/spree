require 'spec_helper'

describe Spree::GraphqlController, type: :controller do
  # TODO: [SGQL-1] Add specs for failed token and access denied
  context 'JWT token access' do
    context 'authorized request' do
      let(:user) { create :user }
      let(:access_token) { Spree::JwtToken.create_for_user(user)[:token] }
      let(:bearer) { "Bearer #{access_token}" }

      before { request.headers['X-Spree-JWT-Token'] = bearer }

      it do
        post :create
        expect(response.status).to eq(200)
        expect(assigns(:spree_current_user)).to eq user
      end
    end
  end
end
