require 'spec_helper'

describe Spree::Admin::StoresController do
  stub_authorization!
  render_views

  let(:store) { create(:store) }
  let(:user) { create(:admin_user) }
  let!(:uk_country) { create(:country, iso: 'GB', iso3: 'GBR', name: 'United Kingdom') }

  before do
    allow(controller).to receive(:current_store).and_return(store)
    allow(controller).to receive(:try_spree_current_user).and_return(user)

    store.add_user(user)

    allow(Spree).to receive(:root_domain).and_return('lvh.me')
  end

  describe 'GET #edit' do
    subject { get :edit }

    it 'renders the edit template' do
      subject
      expect(response).to render_template('spree/admin/stores/edit')
    end

    context 'checkout form' do
      subject { get :edit, params: { section: 'checkout' } }

      it 'renders the checkout form' do
        subject
        expect(response.body).to include('Checkout Settings')
      end
    end
  end

  describe 'PUT #update' do
    subject { patch :update, params: { id: store.to_param, store: store_params, **other_params } }

    let(:store_params) do
      {
        name: 'New Store Name',
        default_currency: 'GBR',
        default_locale: 'pl',
        preferred_timezone: 'Europe/Warsaw',
        preferred_weight_unit: 'kg',
        preferred_unit_system: 'metric'
      }
    end

    let(:other_params) { {} }

    it 'updates the store data' do
      subject

      expect(store.reload.name).to eq('New Store Name')
      expect(store.default_currency).to eq('GBR')
      expect(store.default_locale).to eq('pl')

      expect(store.preferred_timezone).to eq('Europe/Warsaw')
      expect(store.preferred_weight_unit).to eq('kg')
      expect(store.preferred_unit_system).to eq('metric')
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
