require 'spec_helper'

describe Spree::Admin::StoresController do
  stub_authorization!
  render_views

  let(:store) { create(:store) }
  let(:user) { create(:admin_user) }
  let(:user2) { create(:admin_user) }
  let!(:uk_country) { create(:country, iso: 'GB', iso3: 'GBR', name: 'United Kingdom') }

  before do
    allow(controller).to receive(:current_store).and_return(store)
    allow(controller).to receive(:try_spree_current_user).and_return(user)

    store.add_user(user)
    store.add_user(user2)

    allow(Spree).to receive(:root_domain).and_return('lvh.me')
  end

  describe 'POST #create' do
    subject { post :create, params: { store: store_params }, format: :turbo_stream }

    let(:store_params) do
      {
        name: 'New UK Store',
        default_currency: 'GBR',
        default_country_iso: 'GB',
        default_locale: 'en'
      }
    end

    it 'creates a new store' do
      expect(store.users).to contain_exactly(user, user2)
      expect { subject }.to change(Spree::Store, :count).by(1).and change(Spree::RoleUser, :count).by(2)

      expect(flash[:success]).to match('has been successfully created')

      new_store = Spree::Store.last
      expect(new_store.name).to eq('New UK Store')
      expect(new_store.default_currency).to eq('GBR')
      expect(new_store.default_country).to eq(uk_country)
      expect(new_store.default_locale).to eq('en')
      expect(new_store.users).to contain_exactly(user, user2)
    end
  end

  describe 'PUT #update' do
    subject { patch :update, params: { id: store.id, store: store_params, **other_params } }

    let(:store_params) do
      {
        name: 'New Store Name',
        default_currency: 'GBR',
        default_country_iso: 'GB',
        default_locale: 'pl',
        preferred_timezone: 'Europe/Warsaw',
        preferred_weight_unit: 'kg',
        preferred_unit_system: 'metric'
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
