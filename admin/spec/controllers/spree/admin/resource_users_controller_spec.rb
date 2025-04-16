require 'spec_helper'

RSpec.describe Spree::Admin::ResourceUsersController, type: :controller do
  render_views

  let(:store) { @default_store }
  let(:admin_user) { create(:admin_user) }
  let(:role) { Spree::Role.find_or_create_by!(name: 'admin') }

  describe 'GET #index' do
    stub_authorization!

    before do
      admin_user
      get :index
    end

    it 'returns a successful response' do
      expect(response).to be_successful
    end

    it 'assigns @search' do
      expect(assigns(:search)).to be_a(Ransack::Search)
    end

    it 'assigns @collection' do
      expect(assigns(:collection)).to be_a(ActiveRecord::Relation)
      expect(assigns(:collection)).to include(admin_user)
    end
  end

  describe 'GET #show' do
    stub_authorization!

    before { get :show, params: { id: admin_user.id } }

    it 'returns a successful response' do
      expect(response).to be_successful
    end

    it 'assigns @admin_user' do
      expect(assigns(:admin_user)).to eq(admin_user)
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

    let(:valid_params) do
      {
        id: admin_user.id,
        admin_user: {
          first_name: 'Updated',
          last_name: 'Name'
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
        expect(response).to redirect_to([:edit, :admin, store, admin_user])
      end

      it 'sets a flash message' do
        expect(flash[:notice]).not_to be_nil
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
end
