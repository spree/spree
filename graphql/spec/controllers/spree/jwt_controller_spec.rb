require 'spec_helper'

describe Spree::JwtController, type: :controller do
  # TODO: [SGQL-1] Add specs for failed token and access denied
  context 'create' do
    let!(:user) { create :user }

    before do
      allow(controller).to receive(:spree_current_user).and_return(user)
    end

    it do
      post :create, params: { email: user.email, password: user.password }
      expect(json_response['token']).to be_present
      expect(json_response['exp']).to be_present
      expect(json_response['login']).to be_present
    end
  end
end
