require 'spec_helper'

describe Spree::Admin::MultiStore::StoresController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { Spree::Store.default }

  before do
    allow(controller).to receive(:current_store).and_return(store)
    allow(Spree).to receive(:root_domain).and_return('lvh.me')
  end

  describe 'GET #new' do
    subject { get :new }

    it 'renders the new template' do
      subject
      expect(response).to have_http_status(:ok)
    end

    it 'initializes a new store' do
      subject
      expect(assigns(:store)).to be_a_new(Spree::Store)
    end
  end

  describe 'POST #create' do
    subject { post :create, params: { store: store_params } }

    let!(:country) { Spree::Country.find_by(iso: 'US') || create(:country_us) }
    let!(:zone) do
      zone = create(:zone, name: 'US Zone', kind: 'country')
      zone.zone_members.create!(zoneable: country)
      create(:shipping_method, zones: [zone])
      zone
    end
    let(:store_params) do
      {
        name: 'New Store',
        default_country_iso: country.iso
      }
    end

    context 'with valid params' do
      it 'creates a new store' do
        expect { subject }.to change(Spree::Store, :count).by(1)
      end

      it 'creates a default market with the selected country' do
        subject
        new_store = Spree::Store.last
        expect(new_store.markets.count).to eq(1)

        market = new_store.markets.first
        expect(market.name).to eq(country.name)
        expect(market).to be_default
        expect(market.countries).to include(country)
      end

      it 'sets the mail_from_address from the current store' do
        subject
        expect(Spree::Store.last.mail_from_address).to eq(store.mail_from_address)
      end

      it 'copies users to the new store' do
        admin_user = create(:admin_user)
        store.add_user(admin_user)

        subject

        new_store = Spree::Store.last
        expect(new_store.users).to include(admin_user)
      end

      it 'auto-generates URL from code and root_domain' do
        subject
        new_store = Spree::Store.last
        expect(new_store.url).to include('lvh.me')
      end

      it 'redirects to the getting started page on the new store' do
        subject
        new_store = Spree::Store.last
        expect(response).to redirect_to(spree.admin_getting_started_url(host: new_store.url))
      end
    end

    context 'without country' do
      let(:store_params) { { name: 'Store Without Country' } }

      it 'creates the store without a market' do
        expect { subject }.to change(Spree::Store, :count).by(1)
        expect(Spree::Store.last.markets.count).to eq(0)
      end
    end

    context 'with invalid params' do
      let(:store_params) { { name: '' } }

      it 'does not create a store' do
        expect { subject }.not_to change(Spree::Store, :count)
      end

      it 'renders the new template' do
        subject
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'with import_products_from_store_id' do
      let!(:product) { create(:product, stores: [store]) }

      let(:store_params) do
        {
          name: 'Store With Products',
          default_country_iso: country.iso,
          import_products_from_store_id: store.id
        }
      end

      it 'imports products from the source store' do
        subject
        new_store = Spree::Store.last
        expect(new_store.products).to include(product)
      end
    end
  end
end
