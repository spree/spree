require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::DeliveryMethods::RulesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:delivery_method) { create(:shipping_method, name: 'Standard') }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    let!(:rule) do
      Spree::DeliveryMethodRules::ItemTotalRule.create!(
        delivery_method: delivery_method, preferences: { minimum_amount: 25 }
      )
    end

    it 'lists the method rules with schema-driven config' do
      get :index, params: { delivery_method_id: delivery_method.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row['type']).to eq('item_total_rule')
      expect(row['active']).to be(true)
      expect(row['preferences']['minimum_amount']).to eq(25.0)
      expect(row['preference_schema'].map { |field| field['key'] }).to contain_exactly('minimum_amount', 'maximum_amount')
    end
  end

  describe 'POST #create' do
    it 'creates a rule from the wire shorthand' do
      post :create, params: {
        delivery_method_id: delivery_method.prefixed_id,
        type: 'weight_rule',
        preferences: { maximum_weight: 30 }
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['type']).to eq('weight_rule')
      expect(delivery_method.delivery_method_rules.sole.preferred_maximum_weight).to eq(30)
    end

    it 'rejects unregistered types' do
      post :create, params: { delivery_method_id: delivery_method.prefixed_id, type: 'bogus_rule' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects a duplicate rule kind' do
      Spree::DeliveryMethodRules::WeightRule.create!(delivery_method: delivery_method)

      post :create, params: { delivery_method_id: delivery_method.prefixed_id, type: 'weight_rule' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'creates an excluded-products rule from prefixed product ids' do
      product = create(:product)

      post :create, params: {
        delivery_method_id: delivery_method.prefixed_id,
        type: 'excluded_products_rule',
        product_ids: [product.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['type']).to eq('excluded_products_rule')
      expect(json_response['product_ids']).to eq([product.prefixed_id])
      expect(delivery_method.delivery_method_rules.sole.products).to eq([product])
    end

    it 'rejects products belonging to another store' do
      other_store_product = create(:product, store: create(:store))

      post :create, params: {
        delivery_method_id: delivery_method.prefixed_id,
        type: 'excluded_products_rule',
        product_ids: [other_store_product.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(delivery_method.delivery_method_rules.count).to eq(0)
    end
  end

  describe 'PATCH #update' do
    let!(:rule) { Spree::DeliveryMethodRules::ItemTotalRule.create!(delivery_method: delivery_method) }

    it 'updates preferences and active flag' do
      patch :update, params: {
        delivery_method_id: delivery_method.prefixed_id,
        id: rule.prefixed_id,
        active: false,
        preferences: { minimum_amount: 50 }
      }, as: :json

      expect(response).to have_http_status(:ok)
      rule.reload
      expect(rule.active).to be(false)
      expect(rule.preferred_minimum_amount).to eq(50)
    end

    it 'replaces the excluded products' do
      kept = create(:product)
      dropped = create(:product)
      excluded_rule = Spree::DeliveryMethodRules::ExcludedProductsRule.create!(
        delivery_method: delivery_method, products: [dropped]
      )

      patch :update, params: {
        delivery_method_id: delivery_method.prefixed_id,
        id: excluded_rule.prefixed_id,
        product_ids: [kept.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['product_ids']).to eq([kept.prefixed_id])
      expect(excluded_rule.reload.products).to eq([kept])
    end
  end

  describe 'DELETE #destroy' do
    let!(:rule) { Spree::DeliveryMethodRules::ItemTotalRule.create!(delivery_method: delivery_method) }

    it 'removes the rule' do
      delete :destroy, params: { delivery_method_id: delivery_method.prefixed_id, id: rule.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(delivery_method.delivery_method_rules.count).to eq(0)
    end
  end
end
