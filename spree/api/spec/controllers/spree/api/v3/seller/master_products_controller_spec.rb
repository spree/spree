require 'spec_helper'

# The marketplace's shared catalog as a seller browsing it sees it — the one
# seller-branch collection rooted in the store rather than in the seller
# (docs/plans/6.0-seller-master-catalog-listings.md).
RSpec.describe Spree::Api::V3::Seller::MasterProductsController, type: :controller do
  render_views

  include_context 'API v3 Seller'

  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end
  let(:token) do
    Spree::Api::V3::TestingSupport.generate_jwt(
      seller_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER
    )
  end

  let!(:opened) do
    create(:product, name: 'Opened Lamp', store: store, status: 'active', open_to_sellers: true)
  end
  let!(:closed) do
    create(:product, name: 'Closed Lamp', store: store, status: 'active', open_to_sellers: false)
  end

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #index' do
    it 'lists the products the operator opened' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].pluck('name')).to contain_exactly('Opened Lamp')
    end

    # Closed by default, so a marketplace that has not thought about this
    # shares nothing.
    it 'hides a product nobody opened' do
      get :index, as: :json

      expect(json_response['data'].pluck('name')).not_to include('Closed Lamp')
    end

    it 'hides a product another seller owns outright' do
      other = create(:seller, :approved, store: store)
      create(:product, name: 'Their Lamp', store: store, status: 'active',
                       seller: other, open_to_sellers: true)

      get :index, as: :json

      expect(json_response['data'].pluck('name')).not_to include('Their Lamp')
    end

    it 'hides a draft product' do
      opened.update!(status: 'draft')

      get :index, as: :json

      expect(json_response['data']).to be_empty
    end

    it 'hides another store\'s catalog' do
      elsewhere = create(:store)
      create(:product, name: 'Elsewhere Lamp', store: elsewhere, status: 'active', open_to_sellers: true)

      get :index, as: :json

      expect(json_response['data'].pluck('name')).not_to include('Elsewhere Lamp')
    end

    it 'searches by name so a seller can find what they hold' do
      create(:product, name: 'Opened Desk', store: store, status: 'active', open_to_sellers: true)

      get :index, params: { q: { name_cont: 'Desk' } }, as: :json

      expect(json_response['data'].pluck('name')).to contain_exactly('Opened Desk')
    end
  end

  describe 'GET #show' do
    it 'serializes a product the operator opened' do
      get :show, params: { id: opened.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('Opened Lamp')
    end

    # A seller sees rival offers exactly as a shopper does, so the store
    # serializer is the contract — never the admin one.
    it "withholds a rival's cost price on the variants expand" do
      rival = create(:seller, :approved, store: store)
      create(:variant, product: opened, seller: rival, cost_price: 4)

      get :show, params: { id: opened.prefixed_id, expand: 'variants' }, as: :json

      variant = json_response['variants'].last
      expect(variant).to have_key('seller_id')
      expect(variant).not_to have_key('cost_price')
    end

    it '404s a product nobody opened' do
      get :show, params: { id: closed.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
