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
end
