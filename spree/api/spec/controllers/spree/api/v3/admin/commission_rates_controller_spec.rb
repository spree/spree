require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CommissionRatesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:rate) { create(:commission_rate, store: store, name: 'Standard', value: 10) }
  let(:seller) { create(:seller, store: store) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists the store rates with their targeting' do
      create(:commission_seller_rule, commission_rate: rate, sellers: [seller])

      get :index, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row['id']).to start_with('crate_')
      expect(row['name']).to eq('Standard')
      expect(row['kind']).to eq('percentage')
      expect(row['rules'].first).to include('type' => 'seller_rule', 'label' => 'Seller')
    end

    it 'returns rates in precedence order' do
      create(:commission_rate, store: store, name: 'Second')
      third = create(:commission_rate, store: store, name: 'Third')
      third.insert_at(1)
      rate.insert_at(2)

      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].pluck('name')).to eq(['Third', 'Standard', 'Second'])
      expect(json_response['data'].pluck('position')).to eq([1, 2, 3])
    end

    it "hides another marketplace's rates" do
      other = create(:commission_rate, store: create(:store))

      get :index, as: :json

      expect(json_response['data'].map { |row| row['id'] }).not_to include(other.prefixed_id)
    end
  end

  describe 'GET #show' do
    it 'refuses a rate belonging to another store' do
      other = create(:commission_rate, store: create(:store))

      get :show, params: { id: other.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'creates a rate with its targeting in one request' do
      post :create, params: {
        name: 'Audio sellers',
        kind: 'percentage',
        value: 12.5,
        rules: [{ type: 'seller_rule', preferences: { seller_ids: [seller.prefixed_id] } }]
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['value']).to eq('12.5')
      expect(json_response['rules'].first['type']).to eq('seller_rule')
    end

    it 'refuses a fixed rate that states no amount anywhere' do
      post :create, params: { name: 'Flat', kind: 'fixed', value: 2 }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'refuses a percentage above one hundred' do
      post :create, params: { name: 'Too high', kind: 'percentage', value: 150 }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['error']['code']).to eq('validation_error')
    end

    it 'writes a floor and a cap per currency' do
      post :create, params: {
        name: 'Bounded', kind: 'percentage', value: 10,
        bounds: { 'USD' => { min_amount: '2', max_amount: '20' }, 'PLN' => { max_amount: '80' } }
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['bounds']).to eq(
        'USD' => { 'min_amount' => '2.0', 'max_amount' => '20.0' },
        'PLN' => { 'min_amount' => nil, 'max_amount' => '80.0' }
      )
    end
  end

  describe 'PATCH #update' do
    it 'replaces the targeting wholesale' do
      create(:commission_seller_rule, commission_rate: rate, sellers: [seller])
      category = create(:category, store: store)

      patch :update, params: {
        id: rate.prefixed_id,
        rules: [{ type: 'category_rule', preferences: { category_ids: [category.prefixed_id] } }]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(rate.reload.commission_rules.map(&:class)).to eq([Spree::CommissionRules::CategoryRule])
    end

    # A rule can only name records of its own marketplace. The preference
    # writer checks as it writes, so the caller is told which id was wrong
    # rather than having it silently dropped — and the rate keeps the targeting
    # it had, since a half-applied payload could widen what it charges.
    it 'refuses a rule naming another store record, leaving the targeting alone' do
      create(:commission_seller_rule, commission_rate: rate, sellers: [seller])
      foreign_seller = create(:seller, store: create(:store))

      patch :update, params: {
        id: rate.prefixed_id,
        rules: [{ type: 'seller_rule', preferences: { seller_ids: [foreign_seller.prefixed_id] } }]
      }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(rate.reload.commission_rules.map(&:class)).to eq([Spree::CommissionRules::SellerRule])
    end

    it 'refuses a rule kind nobody registered' do
      patch :update, params: {
        id: rate.prefixed_id,
        rules: [{ type: 'nonsense_rule', preferences: {} }]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'refuses a rule naming a record that no longer exists' do
      patch :update, params: {
        id: rate.prefixed_id,
        rules: [{ type: 'seller_rule', preferences: { seller_ids: ['sel_gone'] } }]
      }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'still accepts an empty list as clearing the targeting' do
      create(:commission_seller_rule, commission_rate: rate, sellers: [seller])

      patch :update, params: { id: rate.prefixed_id, rules: [] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(rate.reload.commission_rules).to be_empty
    end

    # Products are named with the prefixed ids every client sends, and are
    # kept in a table rather than the preferences blob — so unlike the other
    # reference lists they are resolved by the controller.
    it 'links products by their prefixed ids' do
      product = create(:product, store: store)

      patch :update, params: {
        id: rate.prefixed_id,
        rules: [{ type: 'product_rule', product_ids: [product.prefixed_id] }]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(rate.reload.commission_rules.first.products).to eq([product])
    end

    # A rate narrowed to another marketplace's catalog would also read those
    # products' ids straight back through the serializer.
    it 'drops a product this store cannot reach' do
      foreign_product = create(:product, store: create(:store))

      patch :update, params: {
        id: rate.prefixed_id,
        rules: [{ type: 'product_rule', product_ids: [foreign_product.id] }]
      }, as: :json

      expect(rate.reload.commission_rules.first.products).to be_empty
    end

    # The rule kind that could not exist while a rule could only name a record.
    it 'accepts a value band' do
      patch :update, params: {
        id: rate.prefixed_id,
        rules: [{ type: 'item_total_rule', preferences: { min_amount: '50', max_amount: '200' } }]
      }, as: :json

      expect(response).to have_http_status(:ok)
      band = rate.reload.commission_rules.first
      expect(band).to be_a(Spree::CommissionRules::ItemTotalRule)
      expect(band.preferred_min_amount).to eq(50)
    end
  end

  describe 'reordering' do
    # The list is the precedence, so moving a row is how an operator changes
    # which rate wins.
    it 'moves a rate through the list' do
      top = create(:commission_rate, store: store)

      patch :update, params: { id: rate.prefixed_id, position: 1 }, as: :json

      expect(response).to have_http_status(:ok)
      expect(store.commission_rates.ordered.to_a).to eq([rate, top])
    end
  end

  describe 'DELETE #destroy' do
    it 'removes a rate' do
      delete :destroy, params: { id: rate.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::CommissionRate.where(id: rate.id)).to be_empty
    end
  end

  describe 'GET #rule_types' do
    it 'describes every registered rule kind, so a client builds its own editor' do
      get :rule_types, as: :json

      expect(response).to have_http_status(:ok)
      types = json_response['data']
      expect(types.map { |row| row['type'] }).
        to include('seller_rule', 'category_rule', 'product_rule', 'item_total_rule')

      band = types.find { |row| row['type'] == 'item_total_rule' }
      expect(band['name']).to eq('Sale value')
      expect(band['preference_schema'].map { |field| field['key'] }).to include('min_amount', 'max_amount')

      products = types.find { |row| row['type'] == 'product_rule' }
      expect(products['association_fields']).to include('product_ids')
    end
  end
end
