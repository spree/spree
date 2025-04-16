require 'spec_helper'

RSpec.describe Spree::Admin::ResourceUsersController, type: :controller do
  render_views

  stub_authorization!

  let(:store) { @default_store }
  let!(:resource_user) { create(:resource_user, resource: store) }

  describe '#destroy' do
    it 'deletes the resource user' do
      expect(store.resource_users.count).to eq(1)

      delete :destroy, params: { id: resource_user.id, store_id: store.id }

      expect(response).to redirect_to(spree.admin_admin_users_path)
      expect(flash[:notice]).to eq("Resource user \"#{resource_user.user.name}\" has been successfully removed!")
      expect(store.resource_users.count).to eq(0)
    end
  end
end
