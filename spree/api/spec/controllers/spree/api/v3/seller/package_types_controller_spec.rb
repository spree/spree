require 'spec_helper'

# A seller measures their own packaging and reads the marketplace's, so the
# isolation to check is in both directions: another seller's boxes must be
# invisible, and the operator's must be readable but never writable
# (docs/plans/6.0-seller-package-types.md).
RSpec.describe Spree::Api::V3::Seller::PackageTypesController, type: :controller do
  render_views

  include_context 'API v3 Seller'

  # A role holding only the packaging keys, so the catalog entry is what
  # actually lets these requests through — a broad role would pass even if
  # `package_types` had never been registered.
  let(:seller_role) do
    create(:role, name: 'Seller', resource: seller, permissions: %w[read_package_types write_package_types])
  end

  let(:token) do
    Spree::Api::V3::TestingSupport.generate_jwt(
      seller_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER
    )
  end

  let!(:mine) do
    create(:package_type, store: store, seller: seller, name: 'My Mailer', default: true,
                          length: 30, width: 20, height: 15, weight: 0.4)
  end
  let(:other_seller) { create(:seller, :approved, store: store) }
  let!(:theirs) { create(:package_type, store: store, seller: other_seller, name: 'Their Mailer') }
  let!(:marketplace) { create(:carton_package_type, store: store, name: 'Marketplace Carton') }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #index' do
    it "lists this seller's packaging and the marketplace's, never another seller's" do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      names = json_response['data'].pluck('name')
      expect(names).to include('My Mailer', 'Marketplace Carton')
      expect(names).not_to include('Their Mailer')
    end

    # The seller's own rows come first, so the page limit cuts the shared
    # vocabulary rather than the seller's own measurements — which is what
    # the variant editor's carton picker depends on.
    it 'lists the seller’s own packaging before the marketplace’s' do
      # Names chosen so alphabetical order would put them the other way round.
      create(:carton_package_type, store: store, name: 'AAA marketplace carton')
      create(:carton_package_type, store: store, seller: seller, name: 'ZZZ my carton')

      get :index, params: { kind_eq: 'carton' }, as: :json

      owners = json_response['data'].map { |row| row['editable'] }
      expect(owners).to eq(owners.sort_by { |editable| editable ? 0 : 1 })
      expect(json_response['data'].pluck('name')).to include('ZZZ my carton', 'AAA marketplace carton')
    end

    it 'honours an explicit sort instead' do
      create(:carton_package_type, store: store, name: 'AAA marketplace carton')
      create(:carton_package_type, store: store, seller: seller, name: 'ZZZ my carton')

      get :index, params: { kind_eq: 'carton', sort: 'name' }, as: :json

      expect(json_response['data'].pluck('name').first).to eq('AAA marketplace carton')
    end

    # The settings page asks for this: a list mixing both owners reads as
    # "packaging is configured" while the seller has recorded nothing, which
    # makes the shipping-box requirement look broken rather than outstanding.
    it 'narrows to the seller’s own packaging on request' do
      get :index, params: { owner: 'mine' }, as: :json

      expect(json_response['data'].pluck('name')).to contain_exactly('My Mailer')
    end

    # What the panel renders a marketplace row read-only by.
    it 'marks only the seller’s own rows editable' do
      get :index, as: :json

      editable = json_response['data'].to_h { |row| [row['name'], row['editable']] }
      expect(editable).to eq('My Mailer' => true, 'Marketplace Carton' => false)
    end
  end

  describe 'GET #show' do
    it 'finds its own' do
      get :show, params: { id: mine.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('My Mailer')
    end

    # Readable so a seller can see what they may pack into.
    it "finds the marketplace's" do
      get :show, params: { id: marketplace.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['editable']).to be(false)
    end

    # 404 rather than 403: the caller must not learn whether it exists.
    it "404s on another seller's" do
      get :show, params: { id: theirs.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'creates one owned by this seller' do
      post :create, params: { name: 'Second Mailer', kind: 'box' }, as: :json

      expect(response).to have_http_status(:created)
      created = Spree::PackageType.find_by(name: 'Second Mailer')
      expect(created.seller).to eq(seller)
      expect(created.store).to eq(store)
    end

    # The payload does not get to say whose it is.
    it 'ignores a seller_id in the payload' do
      post :create, params: { name: 'Third Mailer', kind: 'box', seller_id: other_seller.prefixed_id }, as: :json

      expect(Spree::PackageType.find_by(name: 'Third Mailer').seller).to eq(seller)
    end

    # Each owner names their own packaging, so the marketplace's name is free.
    it 'allows the name the marketplace already uses' do
      post :create, params: { name: 'Marketplace Carton', kind: 'carton' }, as: :json

      expect(response).to have_http_status(:created)
      expect(Spree::PackageType.where(name: 'Marketplace Carton').count).to eq(2)
    end

    it 'accepts every field the shared form sends' do
      post :create, params: {
        name: 'Measured Box', kind: 'carton',
        length: 40, width: 30, height: 25, dimensions_unit: 'cm',
        weight: 1.2, max_weight: 20, weight_unit: 'kg',
        default: false, metadata: { supplier: 'Acme' }
      }, as: :json

      expect(response).to have_http_status(:created)
      created = Spree::PackageType.find_by(name: 'Measured Box')
      expect(created.attributes.symbolize_keys.slice(
        :kind, :dimensions_unit, :weight_unit
      )).to eq(kind: 'carton', dimensions_unit: 'cm', weight_unit: 'kg')
      expect([created.length, created.width, created.height, created.weight, created.max_weight].map(&:to_f)).
        to eq([40.0, 30.0, 25.0, 1.2, 20.0])
      expect(created.metadata).to eq('supplier' => 'Acme')
    end

    # One default per owner: promoting the seller's box must not take the
    # marketplace's away.
    it 'leaves the marketplace default alone when marking its own default' do
      marketplace.update!(default: true)

      post :create, params: { name: 'New Default', kind: 'box', default: true }, as: :json

      expect(response).to have_http_status(:created)
      expect(marketplace.reload).to be_default
      expect(mine.reload).not_to be_default
    end
  end

  describe 'PATCH #update' do
    it 'updates its own' do
      patch :update, params: { id: mine.prefixed_id, name: 'Renamed Mailer' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(mine.reload.name).to eq('Renamed Mailer')
    end

    it "404s on another seller's" do
      patch :update, params: { id: theirs.prefixed_id, name: 'Hijacked' }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(theirs.reload.name).to eq('Their Mailer')
    end

    # Readable through show, and still not theirs to change.
    it "404s on the marketplace's" do
      patch :update, params: { id: marketplace.prefixed_id, name: 'Hijacked' }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(marketplace.reload.name).to eq('Marketplace Carton')
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes its own' do
      spare = create(:package_type, store: store, seller: seller, name: 'Spare')

      delete :destroy, params: { id: spare.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::PackageType.where(id: spare.id)).not_to exist
    end

    it "404s on the marketplace's" do
      delete :destroy, params: { id: marketplace.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(Spree::PackageType.where(id: marketplace.id)).to exist
    end

    # Deleting it would leave this seller's parcels quoted with the
    # marketplace's box without anything saying so.
    it 'refuses its own default box' do
      delete :destroy, params: { id: mine.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(Spree::PackageType.where(id: mine.id)).to exist
    end
  end

  describe 'without the packaging permission' do
    let(:seller_role) { create(:role, name: 'Seller', resource: seller, permissions: %w[read_orders]) }

    it 'is forbidden' do
      get :index, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  # A store the seller does not belong to must be unreachable by id, not
  # merely filtered out of the listing.
  describe 'cross-store isolation' do
    it '404s on a package type from another store' do
      foreign = create(:package_type, store: create(:store), name: 'Foreign Box')

      get :show, params: { id: foreign.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
