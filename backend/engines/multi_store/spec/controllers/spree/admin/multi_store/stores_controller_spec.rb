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

    it 'initializes store with current store defaults' do
      subject
      new_store = assigns(:store)
      expect(new_store.default_currency).to eq(store.default_currency)
    end
  end

  describe 'POST #create' do
    subject { post :create, params: { store: store_params } }

    let(:store_params) do
      {
        name: 'New Store',
        default_currency: 'USD',
        default_locale: 'en'
      }
    end

    context 'with valid params' do
      it 'creates a new store' do
        expect { subject }.to change(Spree::Store, :count).by(1)
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
          default_currency: 'USD',
          default_locale: 'en',
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
