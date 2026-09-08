require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::PackageTypesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:carton) { create(:carton_package_type, store: store, name: 'Master carton') }

  before { request.headers.merge!(headers) }

  it 'lists the packaging this store uses' do
    get :index, as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response['data'].map { |row| row['id'] }).to include(carton.prefixed_id)
  end

  it 'reports the cubic meters a merchant tiers freight on' do
    get :show, params: { id: carton.prefixed_id }, as: :json

    expect(json_response['volume'].to_d).to eq(BigDecimal('0.03'))
    expect(json_response['dimensions_unit']).to eq('cm')
  end

  it 'creates a package type' do
    expect do
      post :create, params: { name: '40ft container', kind: 'container', length: 1200, width: 235, height: 239 }, as: :json
    end.to change(Spree::PackageType, :count).by(1)

    expect(response).to have_http_status(:created)
  end

  it 'refuses a kind outside the vocabulary' do
    post :create, params: { name: 'Crate', kind: 'crate' }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'updates a package type' do
    patch :update, params: { id: carton.prefixed_id, max_weight: 30 }, as: :json

    expect(response).to have_http_status(:ok)
    expect(carton.reload.max_weight).to eq(30)
  end

  it 'moves the default flag off the row that held it' do
    previous_default = create(:package_type, store: store, default: true)

    patch :update, params: { id: carton.prefixed_id, default: true }, as: :json

    expect(previous_default.reload).not_to be_default
    expect(store.default_package_type).to eq(carton)
  end

  it 'deletes a package type nothing is packed into' do
    expect { delete :destroy, params: { id: carton.prefixed_id }, as: :json }.
      to change(Spree::PackageType, :count).by(-1)
  end

  # The operator sees every owner's packaging in their store, so the list has
  # to say whose each row is and narrow to one owner on request
  # (docs/plans/6.0-seller-package-types.md).
  describe 'a marketplace with sellers' do
    let(:seller) { create(:seller, :approved, store: store) }
    let!(:sellers_box) { create(:package_type, store: store, seller: seller, name: 'Seller mailer') }

    it 'lists every owner’s packaging' do
      get :index, as: :json

      expect(json_response['data'].pluck('name')).to include('Master carton', 'Seller mailer')
    end

    it 'names the owner of each row' do
      get :show, params: { id: sellers_box.prefixed_id }, as: :json

      expect(json_response['seller_id']).to eq(seller.prefixed_id)
      expect(json_response['seller_name']).to eq(seller.name)
    end

    it 'reads the marketplace’s own rows as unowned' do
      get :show, params: { id: carton.prefixed_id }, as: :json

      expect(json_response['seller_id']).to be_nil
      expect(json_response['seller_name']).to be_nil
    end

    it 'narrows the list to one seller' do
      get :index, params: { q: { seller_id_eq: seller.id } }, as: :json

      expect(json_response['data'].pluck('name')).to contain_exactly('Seller mailer')
    end

    # A row the operator writes is the marketplace's: ownership is not
    # something the payload gets to claim.
    it 'ignores a seller_id in the payload' do
      post :create, params: { name: 'Operator box', kind: 'box', seller_id: seller.prefixed_id }, as: :json

      expect(response).to have_http_status(:created)
      expect(Spree::PackageType.find_by(name: 'Operator box').seller_id).to be_nil
    end
  end

  it 'cannot reach another store package type' do
    foreign = create(:carton_package_type, store: create(:store))

    get :show, params: { id: foreign.prefixed_id }, as: :json

    expect(response).to have_http_status(:not_found)
  end
end
