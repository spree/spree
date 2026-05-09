# Confirms the parent-from-route inference works for every first-class parent
# the route concern is applied to. One smoke test per parent is enough — the
# CRUD logic is covered by the products-scoped controller spec.
require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CustomFieldsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  shared_examples 'parent-from-route inference' do |parent_factory:, definition_trait:, param_key:|
    let!(:parent) { create(parent_factory) }
    let!(:definition) { create(:metafield_definition, definition_trait) }
    let!(:custom_field) do
      create(:metafield, resource: parent, metafield_definition: definition,
                         type: definition.metafield_type,
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

  # Regression: previously the controller skipped the `customer` alias unless
  # `enabled_resources.include?(Spree.user_class)` returned true — a check that
  # broke after dev-mode class reloads because `enabled_resources` held stale
  # class objects. The route is the source of truth, so the alias is now
  # unconditional. This test exercises that by removing user_class from the
  # configured resources.
  describe 'with user_class missing from enabled_resources' do
    let!(:parent) { create(:user) }
    let!(:definition) { create(:metafield_definition, :for_user) }
    let!(:custom_field) do
      create(:metafield, resource: parent, metafield_definition: definition,
                         type: definition.metafield_type, value: 'value-for-parent')
    end

    before do
      @original_resources = Rails.application.config.spree.metafields.enabled_resources
      Rails.application.config.spree.metafields.enabled_resources = @original_resources - [Spree.user_class]
    end

    after { Rails.application.config.spree.metafields.enabled_resources = @original_resources }

    it 'still resolves customer parent from route' do
      get :index, params: { customer_id: parent.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |cf| cf['value'] }).to include('value-for-parent')
    end
  end
end
