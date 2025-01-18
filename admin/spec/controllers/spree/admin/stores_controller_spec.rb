require 'spec_helper'

describe Spree::Admin::StoresController do
  stub_authorization!
  render_views

  let(:store) { Spree::Store.default }
  let!(:uk_country) { create(:country, iso: 'GB', iso3: 'GBR', name: 'United Kingdom') }

  let(:image_file)      { Rack::Test::UploadedFile.new(File.join(Rails.root, 'spec', 'fixtures', 'thinking-cat.jpg'), 'image/jpeg') }
  let(:store_with_logo) { create(:store, logo: image_file) }

  describe 'POST #create' do
    subject { post :create, params: { store: store_params }, format: :turbo_stream }

    let(:store_params) do
      {
        name: 'New UK Store',
        default_currency: 'GBR',
        default_country_iso: 'GB'
      }
    end

    it 'creates a new store' do
      expect { subject }.to change(Spree::Store, :count).by(1)

      expect(flash[:success]).to match('has been successfully created')

      store = Spree::Store.last
      expect(store.name).to eq('New UK Store')
      expect(store.default_currency).to eq('GBR')
      expect(store.default_country).to eq(uk_country)
    end
  end

  describe 'PUT #update' do
    subject { patch :update, params: { id: store.id, store: store_params } }

    let(:store_params) do
      {
        name: 'New Store Name',
        default_currency: 'GBR',
        default_country_iso: 'GB'
      }
    end

    before do
      store.update!(checkout_zone: nil)
    end

    it 'updates the store data' do
      subject

      expect(store.reload.name).to eq('New Store Name')
      expect(store.default_currency).to eq('GBR')
      expect(store.default_country).to eq(uk_country)
    end
  end
end
