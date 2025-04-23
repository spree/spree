require 'spec_helper'

RSpec.describe Spree::Admin::RoleUsersController, type: :controller do
  render_views

  stub_authorization!

  let(:store) { @default_store }
  let!(:role_user) { create(:role_user, resource: store) }

  describe '#destroy' do
    it 'deletes the role user' do
      expect(store.role_users.count).to eq(1)

      delete :destroy, params: { id: role_user.id, store_id: store.id }

      expect(response).to redirect_to(spree.admin_admin_users_path)
      expect(flash[:notice]).to eq("Role user \"#{role_user.user.name}\" has been successfully removed!")
      expect(store.role_users.count).to eq(0)
    end
  end
end
