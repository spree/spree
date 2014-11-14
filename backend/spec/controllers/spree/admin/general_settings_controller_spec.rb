require 'spec_helper'

describe Spree::Admin::GeneralSettingsController, type: :controller do
  let(:user) { create(:user) }
  let(:mock_user) { mock_model Spree.user_class }

  before do
    allow(controller).to receive_messages :spree_current_user => user
    user.spree_roles << Spree::Role.find_or_create_by(name: 'admin')
  end

  context '#clear_cache' do
    it 'grant access to users with an admin role' do
      spree_post :clear_cache
      expect(response.status).to eq(204)
    end
  end
end
