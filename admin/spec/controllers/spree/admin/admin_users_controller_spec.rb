require 'spec_helper'

RSpec.describe Spree::Admin::AdminUsersController, type: :controller do
  render_views

  let(:store) { @default_store }
  let(:admin_user) { create(:admin_user) }
  let(:role) { Spree::Role.find_or_create_by!(name: 'admin') }

  describe 'GET #select_options' do
    stub_authorization!

    let!(:admin_users) { create_list(:admin_user, 3) }

    it 'returns admin users as select options' do
      get :select_options, format: :json

      json = JSON.parse(response.body)
      ids = json.map { |u| u['id'] }
      admin_users.each do |user|
        expect(ids).to include(user.id)
        expect(json).to include({ 'id' => user.id, 'name' => user.email })
      end
    end

    it 'filters by email when q param is provided' do
      target_user = admin_users.first
      get :select_options, params: { q: target_user.email[0..5] }, format: :json

      json = JSON.parse(response.body)
      expect(json.map { |u| u['id'] }).to include(target_user.id)
    end
  end

  describe 'GET #index' do
    stub_authorization!

    before { admin_user }

    it 'returns a successful response' do
      get :index
      expect(response).to be_successful
    end

    it 'assigns @search' do
      get :index
      expect(assigns(:search)).to be_a(Ransack::Search)
    end

    it 'assigns @collection' do
      get :index
      expect(assigns(:collection)).to be_a(ActiveRecord::Relation)
      expect(assigns(:collection)).to include(admin_user)
    end

    context 'when users has roles from different resources' do
      let(:second_store) { create(:store) }
      let(:second_store_role) { create(:role_user, resource: second_store, user: admin_user) }

      before do
        second_store_role
        get :index
      end

      it 'assigns @collection with roles from the current resource' do
        expect(assigns(:collection).first.role_users.first).not_to eq(second_store_role)
        expect(assigns(:collection).first.role_users.size).to eq(1)
      end
    end
  end

  describe 'GET #show' do
    stub_authorization!

    before { get :show, params: { id: admin_user.id } }

    it 'returns a successful response' do
      get :show, params: { id: admin_user.id }
      expect(response).to be_successful
    end

    it 'assigns @admin_user' do
      get :show, params: { id: admin_user.id }
      expect(assigns(:admin_user)).to eq(admin_user)
    end

    context 'when user has roles from different resources' do
      let(:second_store) { create(:store) }
      let(:second_store_role) { create(:role_user, resource: second_store, user: admin_user) }

      before do
        second_store_role
        get :show, params: { id: admin_user.id }
      end

      it 'assigns @role_users with roles from the current resource' do
        expect(assigns(:role_users).first).not_to eq(second_store_role)
        expect(assigns(:role_users).size).to eq(1)
      end
    end
  end

  describe 'GET #new' do
    let!(:invitation) { create(:invitation, inviter: admin_user, email: 'new@example.com', resource: store) }

    before { get :new, params: { token: invitation.token } }

    it 'returns a successful response' do
      expect(response).to be_successful
    end

    it 'assigns @admin_user' do
      expect(assigns(:admin_user)).to be_a_new(Spree.admin_user_class)
    end

    it 'sets the email from the invitation' do
      expect(assigns(:admin_user).email).to eq(invitation.email)
    end

    it 'assigns @invitation' do
      expect(assigns(:invitation)).to eq(invitation)
    end

    context 'with invalid token' do
      it 'raises RecordNotFound' do
        expect do
          get :new, params: { token: 'invalid' }
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'POST #create' do
    let!(:invitation) { create(:invitation, inviter: admin_user, email: 'new@example.com', resource: store, role_id: role.id) }
    let(:valid_params) do
      {
        token: invitation.token,
        admin_user: {
          email: 'new@example.com',
          password: 'password',
          password_confirmation: 'password',
          first_name: 'John',
          last_name: 'Doe'
        }
      }
    end

    context 'with invalid token' do
      it 'raises RecordNotFound' do
        expect do
          post :create, params: { token: 'invalid' }
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with valid parameters' do
      it 'creates a new admin user' do
        expect do
          post :create, params: valid_params
        end.to change(Spree.admin_user_class, :count).by(1)
      end

      it 'accepts the invitation' do
        post :create, params: valid_params
        expect(invitation.reload.accepted?).to be true
      end

      it 'sets the invitee' do
        post :create, params: valid_params
        expect(invitation.reload.invitee).to eq(Spree.admin_user_class.last)
      end

      it 'redirects to admin path' do
        post :create, params: valid_params
        expect(response).to redirect_to(spree.admin_path)
      end

      it 'assigns the role from the invitation' do
        post :create, params: valid_params
        expect(Spree.admin_user_class.last.spree_roles).to include(role)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          token: invitation.token,
          admin_user: {
            email: admin_user.email
          }
        }
      end

      it 'does not create a new admin user' do
        expect do
          post :create, params: invalid_params
        end.not_to change(Spree.admin_user_class, :count)
      end

      it 'renders the new template' do
        post :create, params: invalid_params
        expect(response).to render_template(:new)
      end

      it 'returns unprocessable entity status' do
        post :create, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET #edit' do
    stub_authorization!

    before { get :edit, params: { id: admin_user.id } }

    it 'returns a successful response' do
      expect(response).to be_successful
    end

    it 'assigns @admin_user' do
      expect(assigns(:admin_user)).to eq(admin_user)
    end
  end

  describe 'PUT #update' do
    stub_authorization!

    let(:new_role) { create(:role, name: 'new_role') }

    let(:valid_params) do
      {
        id: admin_user.id,
        admin_user: {
          first_name: 'Updated',
          last_name: 'Name',
          spree_role_ids: [role.id, new_role.id]
        }
      }
    end

    context 'with valid parameters' do
      before { put :update, params: valid_params }

      it 'updates the admin user' do
        admin_user.reload
        expect(admin_user.first_name).to eq('Updated')
        expect(admin_user.last_name).to eq('Name')
      end

      it 'redirects to edit admin user path' do
        expect(response).to redirect_to(spree.admin_admin_user_path(admin_user))
      end

      it 'sets a flash message' do
        expect(flash[:notice]).not_to be_nil
      end

      it 'updates the admin user roles' do
        admin_user.reload
        expect(admin_user.spree_roles).to contain_exactly(role, new_role)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          id: admin_user.id,
          admin_user: {
            email: ''
          }
        }
      end

      before { put :update, params: invalid_params }

      it 'does not update the admin user' do
        expect(admin_user.reload.email).not_to eq('')
      end

      it 'renders the edit template' do
        expect(response).to render_template(:edit)
      end

      it 'returns unprocessable entity status' do
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE #destroy' do
    stub_authorization!

    context 'can delete user' do
      let!(:other_admin) { create(:admin_user) }

      it 'deletes the admin user' do
        expect { delete :destroy, params: { id: admin_user.id } }.to change(Spree.admin_user_class, :count).by(-1)
        expect(response).to redirect_to(spree.admin_admin_users_path)
      end
    end

    context 'cannot delete user' do
      it 'does not delete the admin user' do
        delete :destroy, params: { id: admin_user.id }
        expect(response).to redirect_to(spree.admin_admin_users_path)
        expect(admin_user).not_to be_destroyed
      end
    end
  end
end
