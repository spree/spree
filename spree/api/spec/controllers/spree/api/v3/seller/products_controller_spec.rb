require 'spec_helper'

# The first collection on the seller branch, so this doubles as the proof that
# `Seller::ResourceController` roots everything in the seller. Every later
# collection (orders, returns) inherits exactly this behaviour.
RSpec.describe Spree::Api::V3::Seller::ProductsController, type: :controller do
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

  let!(:mine) { create(:product, name: 'My Lamp', seller: seller, store: store) }
  let(:other_seller) { create(:seller, :approved, store: store) }
  let!(:theirs) { create(:product, name: 'Their Lamp', seller: other_seller, store: store) }
  let!(:first_party) { create(:product, name: 'Marketplace Lamp', store: store) }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #index' do
    it "lists only this seller's products" do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      names = json_response['data'].pluck('name')
      expect(names).to include('My Lamp')
      expect(names).not_to include('Their Lamp', 'Marketplace Lamp')
    end

    it 'exposes status, which the storefront serializer withholds' do
      get :index, as: :json

      expect(json_response['data'].first).to include('status')
    end
  end

  describe 'GET #show' do
    it 'returns their own product' do
      get :show, params: { id: mine.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('My Lamp')
    end

    # 404, not 403: the caller cannot tell whether the id exists at all.
    it "404s on another seller's product" do
      get :show, params: { id: theirs.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it '404s on a first-party product' do
      get :show, params: { id: first_party.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'creates the product as this seller, whatever the payload says' do
      post :create,
           params: { name: 'New Lamp', status: 'draft', seller_id: other_seller.prefixed_id },
           as: :json

      expect(response).to have_http_status(:created)
      product = Spree::Product.find_by(name: 'New Lamp')
      expect(product.seller).to eq(seller)
      expect(product.store).to eq(store)
    end

    # A seller has no currency of their own to send, and `Variant#prices=`
    # drops base prices for currencies absent from the payload — so guessing
    # here would not merely add a stray price, it would remove the right one.
    it "prices in the store's currency when the payload names none" do
      # Deliberately not the store factory's USD: a spec asserting USD here
      # would pass just as well against a hardcoded fallback.
      allow(Spree::Current).to receive(:currency).and_return('GBP')

      post :create,
           params: { name: 'Unpriced Lamp', prices: [{ amount: '19.99' }] },
           as: :json

      expect(response).to have_http_status(:created)
      price = Spree::Product.find_by(name: 'Unpriced Lamp').default_variant.prices.first
      expect(price.currency).to eq('GBP')
      expect(price.amount).to eq(19.99)
    end

    it 'honours a currency the payload does name' do
      post :create,
           params: { name: 'Euro Lamp', prices: [{ amount: '19.99', currency: 'EUR' }] },
           as: :json

      expect(response).to have_http_status(:created)
      currencies = Spree::Product.find_by(name: 'Euro Lamp').default_variant.prices.map(&:currency)
      expect(currencies).to eq(['EUR'])
    end
  end

  # A seller lists; the marketplace decides what goes on sale. These are the
  # two halves of that: status is not an attribute they can send, and the
  # actions that do move it never reach `active`.
  describe 'status' do
    # The factory ships products `active`, so a draft is stated explicitly
    # wherever the case needs one.
    let!(:unlisted) { create(:product, name: 'Unlisted', seller: seller, store: store, status: 'draft') }

    it 'is not writable through update' do
      patch :update, params: { id: unlisted.prefixed_id, status: 'active' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(unlisted.reload).to be_draft
    end

    it 'submits for review' do
      patch :submit, params: { id: unlisted.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(unlisted.reload).to be_proposed
    end

    it 'takes a listing back down' do
      patch :draft, params: { id: mine.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(mine.reload).to be_draft
    end

    it 'archives a listing' do
      patch :archive, params: { id: mine.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(mine.reload).to be_archived
    end

    it "cannot submit another seller's product" do
      other_draft = create(:product, seller: other_seller, store: store, status: 'draft')

      patch :submit, params: { id: other_draft.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(other_draft.reload).to be_draft
    end

    it 'refuses to submit a product already on sale' do
      patch :submit, params: { id: mine.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(mine.reload).to be_active
    end
  end

  # The panel loads a product into a form and sends it back, so anything the
  # controller accepts must come back out — otherwise a save blanks it.
  it 'returns every field it accepts on write' do
    mine.update!(metadata: { 'care' => 'wash cold' })

    get :show, params: { id: mine.prefixed_id }, as: :json

    expect(json_response).to include(
      'name', 'description', 'slug',
      'meta_title', 'meta_description', 'meta_keywords', 'metadata'
    )
    expect(json_response['metadata']).to eq('care' => 'wash cold')
  end

  # How a product is filed is the marketplace's own merchandising, so the
  # seller serializer adds none of it — a field a seller cannot change should
  # not be shown as though they could. (`tags` rides in from the storefront
  # serializer, where it is public product data; it is simply not writable.)
  it 'withholds the marketplace merchandising fields' do
    get :show, params: { id: mine.prefixed_id }, as: :json

    expect(json_response).not_to include('product_type_id', 'category_ids', 'collection_ids')
  end

  # The form loads a product with everything it edits in one request, so each
  # of these has to resolve — a missing seller-side serializer raises rather
  # than quietly omitting the key.
  it 'expands the collections the form edits' do
    get :show,
        params: { id: mine.prefixed_id, expand: 'variants,media,default_variant' },
        as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response).to include('variants', 'media', 'default_variant')
  end

  describe 'writing variants, media and memberships' do
    let(:category) { create(:category, store: store) }

    it 'saves a variant the payload carries' do
      patch :update,
            params: {
              id: mine.prefixed_id,
              variants: [{ sku: 'LAMP-1', barcode: '5060', options: [] }]
            },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(mine.reload.variants.map(&:sku)).to include('LAMP-1')
    end

    # `Variant#stock_levels=` resolves a location against the product's store,
    # which on a marketplace spans every seller — so the ids are narrowed to
    # this seller's before the payload gets there.
    it "cannot write stock into another seller's warehouse" do
      rival = create(:seller, :approved, store: store)
      rival_location = create(:stock_location, store: store, seller: rival)

      patch :update,
            params: {
              id: mine.prefixed_id,
              variants: [{
                id: mine.default_variant.prefixed_id, options: [],
                stock_levels: [{ stock_location_id: rival_location.prefixed_id, count_on_hand: 99 }]
              }]
            },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(Spree::StockLevel.find_by(stock_location: rival_location, variant: mine.default_variant)).to be_nil
    end

    it 'writes stock into its own warehouse' do
      own_location = create(:stock_location, store: store, seller: seller)

      patch :update,
            params: {
              id: mine.prefixed_id,
              variants: [{
                id: mine.default_variant.prefixed_id, options: [],
                stock_levels: [{ stock_location_id: own_location.prefixed_id, count_on_hand: 7 }]
              }]
            },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(
        Spree::StockLevel.find_by(stock_location: own_location, variant: mine.default_variant).count_on_hand
      ).to eq(7)
    end

    it 'attaches an uploaded image' do
      blob = ActiveStorage::Blob.create_and_upload!(
        io: File.open(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')),
        filename: 'lamp.jpg',
        content_type: 'image/jpeg'
      )

      patch :update,
            params: { id: mine.prefixed_id, media: [{ signed_id: blob.signed_id, alt: 'A lamp' }] },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(mine.reload.media.map(&:alt)).to include('A lamp')
    end

    # Tags are tenanted to the store, so a seller writing one would be adding
    # a term to the marketplace's own vocabulary rather than labelling their
    # product (docs/plans/6.0-multi-vendor-marketplace.md).
    it 'ignores tags' do
      patch :update, params: { id: mine.prefixed_id, tags: ['seller-coined'] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(mine.reload.tag_list).to be_empty
    end

    it 'cannot file the product under a category' do
      patch :update, params: { id: mine.prefixed_id, category_ids: [category.prefixed_id] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(mine.reload.categories).to be_empty
    end

    it 'cannot set a product type' do
      product_type = create(:product_type, store: store)

      patch :update, params: { id: mine.prefixed_id, product_type_id: product_type.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(mine.reload.product_type).to be_nil
    end

    # Marketplace configuration, not a seller's: silently ignored rather than
    # refused, the same way tax and delivery already are on this endpoint.
    # Asserted on the column, since the reader falls back to the store default.
    it 'ignores a tax category on a variant' do
      tax_category = create(:tax_category, store: store)

      patch :update,
            params: {
              id: mine.prefixed_id,
              variants: [{ sku: 'LAMP-2', tax_category_id: tax_category.prefixed_id, options: [] }]
            },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(mine.reload.variants.find_by(sku: 'LAMP-2')[:tax_category_id]).to be_nil
    end
  end

  describe 'PATCH #update' do
    it 'edits their own product' do
      patch :update, params: { id: mine.prefixed_id, name: 'Renamed Lamp' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(mine.reload.name).to eq('Renamed Lamp')
    end

    it "cannot edit another seller's product" do
      patch :update, params: { id: theirs.prefixed_id, name: 'Hijacked' }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(theirs.reload.name).to eq('Their Lamp')
    end

    # The reason the marketplace gave lived in product metadata once, which
    # the seller writes — so an ordinary save erased the operator's decision.
    it 'cannot erase why the marketplace sent the product back' do
      mine.update!(status: 'proposed')
      Spree.product_reject_workflow.call(product: mine, reason: 'Photos are too dark')

      patch :update, params: { id: mine.prefixed_id, metadata: { care: 'wash cold' } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(mine.reload.rejection_reason).to eq('Photos are too dark')
    end

    # Reaching `active` is the marketplace's call, and a status sent in an
    # update payload records nobody as having made it.
    it 'cannot put its own product on sale through an update' do
      mine.update!(status: 'proposed')

      patch :update, params: { id: mine.prefixed_id, status: 'active' }, as: :json

      expect(mine.reload).to be_proposed
    end

    # Marketplace configuration stays with the operator.
    it 'ignores tax and delivery configuration' do
      other_tax = create(:tax_category)

      patch :update, params: { id: mine.prefixed_id, tax_category_id: other_tax.prefixed_id }, as: :json

      expect(mine.reload.tax_category).not_to eq(other_tax)
    end
  end

  describe 'DELETE #destroy' do
    it "cannot delete another seller's product" do
      delete :destroy, params: { id: theirs.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(theirs.reload).to be_present
    end
  end

  # A member whose role lacks the products key is refused by the gate before
  # the scope is even consulted.
  context 'without write_products' do
    let(:narrow_role) { create(:role, name: 'Viewer', resource: seller, permissions: %w[read_products]) }
    let(:seller_user) do
      create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user, narrow_role) }
    end

    it 'can read' do
      get :index, as: :json
      expect(response).to have_http_status(:ok)
    end

    it 'cannot write' do
      patch :update, params: { id: mine.prefixed_id, name: 'Nope' }, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end
end
