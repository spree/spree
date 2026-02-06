require 'spec_helper'

describe Spree::Admin::OauthApplicationsController, type: :controller do
  stub_authorization!

  render_views

  describe '#index' do
    let!(:oauth_application) { create(:oauth_application) }

    it 'responds successfully' do
      get :index
      expect(response).to be_successful
    end
  end

  describe '#new' do
    it 'responds successfully' do
      get :new
      expect(response).to be_successful
    end

    it 'sets default scopes to admin' do
      get :new
      expect(assigns(:object).scopes.to_s).to eq('admin')
    end
  end

  describe '#create' do
    let(:params) do
      {
        oauth_application: {
          name: 'Test App',
          scopes: 'admin read'
        }
      }
    end

    it 'creates a new oauth application' do
      expect {
        post :create, params: params
      }.to change(Spree::OauthApplication, :count).by(1)
    end

    it 'sets the attributes' do
      post :create, params: params
      oauth_app = Spree::OauthApplication.last
      expect(oauth_app.name).to eq('Test App')
      expect(oauth_app.scopes.to_s).to eq('admin read')
    end

    it 'redirects to index with success flash' do
      post :create, params: params
      oauth_app = Spree::OauthApplication.last
      expect(response).to redirect_to(spree.edit_admin_oauth_application_path(oauth_app))
      expect(flash[:success]).to be_present
    end
  end

  describe '#edit' do
    let!(:oauth_application) { create(:oauth_application) }

    it 'responds successfully' do
      get :edit, params: { id: oauth_application.id }
      expect(response).to be_successful
    end

    it 'sets default scopes to admin if blank' do
      oauth_application.update(scopes: '')
      get :edit, params: { id: oauth_application.id }
      expect(assigns(:object).scopes.to_s).to eq('admin')
    end
  end

  describe '#update' do
    let!(:oauth_application) { create(:oauth_application) }
    let(:params) do
      {
        id: oauth_application.id,
        oauth_application: {
          name: 'Updated App',
          scopes: 'admin write'
        }
      }
    end

    it 'updates the oauth application' do
      put :update, params: params
      oauth_application.reload
      expect(oauth_application.name).to eq('Updated App')
      expect(oauth_application.scopes.to_s).to eq('admin write')
    end

    it 'redirects to index with success flash' do
      put :update, params: params
      expect(response).to redirect_to(spree.edit_admin_oauth_application_path(oauth_application))
      expect(flash[:success]).to be_present
    end
  end

  describe '#destroy' do
    let!(:oauth_application) { create(:oauth_application) }

    it 'destroys the oauth application' do
      expect {
        delete :destroy, params: { id: oauth_application.id }
      }.to change(Spree::OauthApplication, :count).by(-1)
    end

    it 'redirects to index with success flash' do
      delete :destroy, params: { id: oauth_application.id }
      expect(response).to redirect_to(spree.admin_oauth_applications_path)
      expect(flash[:success]).to be_present
    end
  end
end
