require 'spec_helper'

RSpec.describe Spree::Admin::RolesController, type: :controller do
  stub_authorization!
  render_views

  describe 'GET #index' do
    let!(:roles) { create_list(:role, 3) }

    it 'renders the list of roles' do
      get :index

      expect(response).to be_successful
      expect(response).to render_template(:index)

      expect(assigns(:roles)).to contain_exactly(*roles, Spree::Role.default_admin_role)
    end
  end

  describe 'GET #new' do
    it 'renders the new role form' do
      get :new

      expect(response).to be_successful
      expect(response).to render_template(:new)
    end
  end

  describe 'POST #create' do
    let(:role_params) do
      {
        name: 'Default Role'
      }
    end

    let(:role) { Spree::Role.last }

    it 'creates a new role' do
      post :create, params: { role: role_params }

      expect(response).to redirect_to(spree.edit_admin_role_path(role))

      expect(role).to be_persisted
      expect(role.name).to eq('Default Role')
    end
  end

  describe 'GET #edit' do
    let!(:role) { create(:role) }

    it 'renders the edit role form' do
      get :edit, params: { id: role.to_param }

      expect(response).to be_successful
      expect(response).to render_template(:edit)
    end
  end

  describe 'PUT #update' do
    let!(:role) { create(:role, name: 'Default Role') }

    it 'updates the role' do
      put :update, params: { id: role.to_param, role: { name: 'Updated Role' } }

      expect(response).to redirect_to(spree.edit_admin_role_path(role))
      expect(role.reload.name).to eq('Updated Role')
    end
  end

  describe 'DELETE #destroy' do
    let!(:role) { create(:role) }

    it 'deletes the role' do
      delete :destroy, params: { id: role.to_param }

      expect(response).to redirect_to(spree.admin_roles_path)
      expect { role.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
