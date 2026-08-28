require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::ExportsController, type: :controller do
  render_views

  include_context 'API v3 Seller'

  # `read_orders` and `read_products` are what the export gate asks for, and
  # the ability resolves them from a role held on the seller.
  let(:seller_role) do
    create(:role, name: 'Seller', resource: seller, permissions: %w[read_orders read_products])
  end

  let!(:mine) { create(:completed_order_with_totals, store: store, seller: seller) }
  let(:other_seller) { create(:seller, :approved, store: store) }
  let!(:theirs) { create(:completed_order_with_totals, store: store, seller: other_seller) }

  before do
    request.headers['Authorization'] = "Bearer #{seller_jwt_token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'POST #create' do
    it 'queues an export owned by the acting seller' do
      post :create, params: { type: 'orders' }, as: :json

      expect(response).to have_http_status(:created)

      export = Spree::Export.find_by(number: json_response['number'])
      expect(export.seller).to eq(seller)
      expect(export.store).to eq(store)
      expect(export.user).to eq(seller_user)
    end

    # The whole point of the branch: tenancy is the scope narrowing, not the
    # ability, which grants the model class store-wide.
    it "writes only this seller's orders into the file" do
      post :create, params: { type: 'orders' }, as: :json

      export = Spree::Export.find_by(number: json_response['number'])
      expect(export.records_to_export).to include(mine)
      expect(export.records_to_export).not_to include(theirs)
    end

    it 'ignores a seller named in the payload' do
      post :create, params: { type: 'orders', seller_id: other_seller.prefixed_id }, as: :json

      export = Spree::Export.find_by(number: json_response['number'])
      expect(export.seller).to eq(seller)
    end

    it 'leaves drafts out' do
      draft = create(:order, store: store, seller: seller, status: 'draft', cart: nil)

      post :create, params: { type: 'orders' }, as: :json

      export = Spree::Export.find_by(number: json_response['number'])
      expect(export.records_to_export).not_to include(draft)
    end

    # Creating one is not proof it works: generation runs in a background job,
    # so a scope that raises there returns 201 here and only surfaces as a
    # download that never arrives.
    it 'accepts a products export and can actually generate it' do
      mine = create(:product, store: store, seller: seller)
      theirs = create(:product, store: store, seller: other_seller)

      post :create, params: { type: 'products' }, as: :json

      expect(response).to have_http_status(:created)

      export = Spree::Export.find_by(number: json_response['number'])
      expect { export.generate }.not_to raise_error
      expect(export.attachment.download).to include(mine.name)
      expect(export.attachment.download).not_to include(theirs.name)
    end

    # A type the operator can export but which cannot be narrowed to one
    # seller must never be reachable here.
    it 'refuses a type outside the seller allowlist' do
      post :create, params: { type: 'customers' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(Spree::Export.count).to eq(0)
    end

    it 'refuses an unknown type' do
      post :create, params: { type: 'nonsense' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'keeps a results_url the store allows' do
      create(:allowed_origin, store: store, origin: 'https://shop.test')

      post :create, params: { type: 'orders', results_url: 'https://shop.test/sellers' }, as: :json

      export = Spree::Export.find_by(number: json_response['number'])
      expect(export.results_url).to eq('https://shop.test/sellers')
    end

    it 'drops a results_url pointing somewhere else' do
      post :create, params: { type: 'orders', results_url: 'https://evil.test/steal' }, as: :json

      export = Spree::Export.find_by(number: json_response['number'])
      expect(export.results_url).to be_nil
    end
  end

  describe 'GET #show' do
    let!(:own_export) { create(:order_export, store: store, seller: seller, user: seller_user) }
    let!(:other_export) do
      create(:order_export, store: store, seller: other_seller)
    end

    it 'reads its own' do
      get :show, params: { id: own_export.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(own_export.prefixed_id)
    end

    # Missing rather than denied — the scope is rooted in the seller's own
    # exports, so another seller's id simply is not there.
    it "cannot read another seller's" do
      get :show, params: { id: other_export.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET #download' do
    let(:export) { create(:order_export, store: store, seller: seller, user: seller_user) }

    it 'refuses while the file is still being written' do
      get :download, params: { id: export.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('export_not_ready')
    end

    it 'streams the file once it is ready' do
      export.generate

      get :download, params: { id: export.reload.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Disposition']).to include('attachment')
      expect(response.body).to include(mine.number)
      expect(response.body).not_to include(theirs.number)
    end

    # The seller order page withholds the buyer's email, so the bulk download
    # of the same orders must not hand it over instead.
    it "withholds the buyer's email while keeping the shipping address" do
      export.generate

      get :download, params: { id: export.reload.prefixed_id }

      expect(response.body).not_to include(mine.email)
      expect(response.body).to include(mine.ship_address.address1)
    end

    it "cannot download another seller's" do
      other = create(:order_export, store: store, seller: other_seller)

      get :download, params: { id: other.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'authorization' do
    it 'refuses a seller whose role does not read orders' do
      seller_role.update!(permissions: %w[read_products])

      post :create, params: { type: 'orders' }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it 'refuses a request naming no seller' do
      request.headers['X-Spree-Seller-Id'] = nil

      post :create, params: { type: 'orders' }, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
