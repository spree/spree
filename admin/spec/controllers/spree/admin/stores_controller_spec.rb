require 'spec_helper'

describe Spree::Admin::StoresController do
  stub_authorization!
  render_views

  let(:store) { Spree::Store.default }
  let!(:uk_country) { create(:country, iso: 'GB', iso3: 'GBR', name: 'United Kingdom') }

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
    subject { patch :update, params: { id: store.id, store: store_params, **other_params } }

    let(:store_params) do
      {
        name: 'New Store Name',
        default_currency: 'GBR',
        default_country_iso: 'GB'
      }
    end

    let(:other_params) { {} }

    before do
      store.update!(checkout_zone: nil)
    end

    it 'updates the store data' do
      subject

      expect(store.reload.name).to eq('New Store Name')
      expect(store.default_currency).to eq('GBR')
      expect(store.default_country).to eq(uk_country)
    end

    context 'when removing assets' do
      let(:image_path) { Spree::Core::Engine.root.join('spec/fixtures/files/icon_256x256.png') }
      let(:image_file) { Rack::Test::UploadedFile.new(image_path, 'image/png') }

      context 'when removing the logo' do
        let(:other_params) { { remove_logo: '1' } }

        before { store.logo.attach(image_file) }

        it 'removes the logo' do
          expect { subject }.to change { store.reload.logo.attached? }.from(true).to(false)
        end
      end

      context 'when removing the mailer logo' do
        let(:other_params) { { remove_mailer_logo: '1' } }

        before { store.mailer_logo.attach(image_file) }

        it 'removes the mailer logo' do
          expect { subject }.to change { store.reload.mailer_logo.attached? }.from(true).to(false)
        end
      end
    end
  end
end
