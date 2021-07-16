require 'spec_helper'

describe Spree::Admin::StoresController do
  stub_authorization!

  let!(:store)          { create(:store) }
  let(:image_file)      { Rack::Test::UploadedFile.new(Spree::Backend::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')) }
  let(:store_with_logo) { create(:store, logo: image_file) }

  describe 'on :index' do
    it 'renders index' do
      get :index

      expect(response).to have_http_status(:ok)
    end
  end

  describe '#create' do
    it 'redirects to stores index page using the newly created store URL' do
      post :create, params: {
        store: { name: 'New Test Store',
                 code: 'NTSS',
                 mail_from_address: 'testing@example.com',
                 url: 'http://test-new-store.lvh.me',
                 default_locale: 'en',
                 default_currency: 'USD',
                 supported_currencies: ['USD,GBP'],
                 supported_locales: ['en'] }
      }

      expect(response).to redirect_to('http://test-new-store.lvh.me/admin/stores')
    end
  end

  context 'update' do
    it 'can update logo' do
      put :update, params: { id: store.to_param, store: { logo: image_file } }

      expect(store.reload.logo.blob.filename).to eq(image_file.original_filename)
    end
  end
end
