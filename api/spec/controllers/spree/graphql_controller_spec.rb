require 'spec_helper'

describe Spree::Graphql::GraphqlController, type: :controller do
  #TODO Add specs for failed token and access denied
  context 'JWT token access' do
    context 'login' do
      let!(:user) { create :user }

      before do
        allow(controller).to receive(:spree_current_user).and_return(user)
      end

      it do
        api_post :login, email: user.email, password: user.password
        expect(json_response['token']).to be_present
        expect(json_response['exp']).to be_present
        expect(json_response['login']).to be_present
      end
    end

    context 'authorized request' do
      let(:user) { create :user }
      let(:access_token) { Spree::JwtToken.create_for_user(user)[:token] }
      let(:bearer) { "Bearer #{access_token}" }

      before { request.headers['X-Spree-JWT-Token'] = bearer }

      it do
        api_post :create
        expect(response.status).to eq(200)
        expect(assigns(:spree_current_user)).to eq user
      end
    end
  end


end
