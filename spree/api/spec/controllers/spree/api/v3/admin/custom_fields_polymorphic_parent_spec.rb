# Confirms the parent-from-route inference works for every first-class parent
# the route concern is applied to. One smoke test per parent is enough — the
# CRUD logic is covered by the products-scoped controller spec.
require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CustomFieldsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  shared_examples 'parent-from-route inference' do |parent_factory:, param_key:, definition_trait: nil, resource_type: nil|
    let!(:parent) { create(parent_factory) }
    let!(:definition) do
      definition_trait ? create(:custom_field_definition, definition_trait) : create(:custom_field_definition, resource_type: resource_type)
    end
    let!(:custom_field) do
      create(:custom_field, resource: parent, custom_field_definition: definition,
                         type: definition.field_type_class_name,
                         value: 'value-for-parent')
    end

    it 'returns the parent\'s custom fields' do
      get :index, params: { param_key => parent.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      values = json_response['data'].map { |cf| cf['value'] }
      expect(values).to include('value-for-parent')
    end
  end

  describe 'orders' do
    include_examples 'parent-from-route inference',
                     parent_factory: :order,
                     definition_trait: :for_order,
                     param_key: :order_id
  end

  describe 'customers' do
    include_examples 'parent-from-route inference',
                     parent_factory: :user,
                     definition_trait: :for_user,
                     param_key: :customer_id
  end

  describe 'variants' do
    include_examples 'parent-from-route inference',
                     parent_factory: :variant,
                     definition_trait: :for_variant,
                     param_key: :variant_id
  end

  {
    promotions: [:promotion, :promotion_id, 'Spree::Promotion'],
    gift_cards: [:gift_card, :gift_card_id, 'Spree::GiftCard'],
    store_credits: [:store_credit, :store_credit_id, 'Spree::StoreCredit'],
    stock_transfers: [:stock_transfer, :stock_transfer_id, 'Spree::StockTransfer'],
    purchase_orders: [:purchase_order, :purchase_order_id, 'Spree::PurchaseOrder'],
    companies: [:company, :company_id, 'Spree::Company'],
    payment_methods: [:check_payment_method, :payment_method_id, 'Spree::PaymentMethod'],
    delivery_methods: [:delivery_method, :delivery_method_id, 'Spree::DeliveryMethod'],
    tax_rates: [:tax_rate, :tax_rate_id, 'Spree::TaxRate'],
    product_types: [:product_type, :product_type_id, 'Spree::ProductType'],
    media: [:media, :medium_id, 'Spree::Media']
  }.each do |name, (parent_factory, param_key, resource_type)|
    describe name.to_s do
      include_examples 'parent-from-route inference',
                       parent_factory: parent_factory, param_key: param_key, resource_type: resource_type
    end
  end

  describe 'the store' do
    let!(:definition) { create(:custom_field_definition, resource_type: 'Spree::Store') }

    it 'writes custom fields on the current store' do
      post :create,
           params: { store_id: store.prefixed_id, custom_field_definition_id: definition.prefixed_id, value: 'EU' },
           as: :json

      expect(response).to have_http_status(:created)
      expect(store.custom_fields.pluck(:value)).to eq(['EU'])
    end

    it 'does not reach another store' do
      other_store = create(:store)

      get :index, params: { store_id: other_store.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  # `Spree::Base.for_store` answers nothing for a model the store has no
  # association for; the lookup refuses rather than searching every store's
  # records.
  describe 'a parent the store cannot scope' do
    let!(:promotion) { create(:promotion) }

    before { allow(Spree::Promotion).to receive(:for_store).and_return(Spree::Promotion.none) }

    it 'returns not found' do
      get :index, params: { promotion_id: promotion.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  # Simulates the dev-mode class-reload condition where
  # `enabled_resources.include?(Spree.customer_class)` returns false because the
  # cached class reference goes stale after Zeitwerk reloads. The customer
  # route must still resolve in that case.
  describe 'when enabled_resources does not contain Spree.customer_class' do
    let!(:parent) { create(:user) }
    let!(:definition) { create(:custom_field_definition, :for_user) }
    let!(:custom_field) do
      create(:custom_field, resource: parent, custom_field_definition: definition,
                         type: definition.field_type_class_name, value: 'value-for-parent')
    end

    before do
      @original_resources = Rails.application.config.spree.custom_fields.enabled_resources
      Rails.application.config.spree.custom_fields.enabled_resources = @original_resources - [Spree.customer_class]
    end

    after { Rails.application.config.spree.custom_fields.enabled_resources = @original_resources }

    it 'returns the customer\'s custom fields' do
      get :index, params: { customer_id: parent.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |cf| cf['value'] }).to include('value-for-parent')
    end
  end
end
