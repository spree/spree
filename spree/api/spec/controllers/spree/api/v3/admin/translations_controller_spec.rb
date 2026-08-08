require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::TranslationsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:product) { create(:product, name: 'Espresso Machine', store: store) }

  before do
    configure_supported_locales(store, %w[en de fr])
    request.headers.merge!(headers)
  end

  describe 'GET #index' do
    before { Mobility.with_locale(:de) { product.update!(name: 'Espressomaschine') } }

    it 'returns the translation matrix, fields, and locales for the parent' do
      get :index, params: { product_id: product.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      data = json_response['data']
      expect(data['resource_type']).to eq('product')
      expect(data['resource_id']).to eq(product.prefixed_id)
      expect(data['default_locale']).to eq('en')
      expect(data['supported_locales']).to match_array(%w[en de fr])
      expect(data['translations']['de']['name']).to eq('Espressomaschine')

      name_field = data['fields'].find { |f| f['key'] == 'name' }
      expect(name_field['source']).to eq('Espresso Machine')
      expect(name_field['type']).to eq('string')
    end

    it 'returns 404 for a missing parent' do
      get :index, params: { product_id: 'prod_NotReal' }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  # The per-parent scope resolves through the catalog: an option type's
  # translations ride the `products` permission, not a literal
  # `option_types` scope that no key or role could ever hold.
  describe 'key gate over polymorphic parents' do
    let!(:option_type) { create(:option_type) }

    context 'as a staffer holding read_products' do
      let(:staffer) do
        create(:admin_user, :without_admin_role).tap do |user|
          user.role_users.create!(role: create(:role, name: 'catalog_viewer', permissions: %w[read_products]), resource: store)
        end
      end
      let(:headers) do
        { 'Authorization' => "Bearer #{Spree::Api::V3::TestingSupport.generate_jwt(staffer, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN)}" }
      end

      it 'reads an option type translation matrix' do
        get :index, params: { option_type_id: option_type.prefixed_id }, as: :json

        expect(response).to have_http_status(:ok)
      end
    end

    context 'as a staffer without a products permission' do
      let(:staffer) do
        create(:admin_user, :without_admin_role).tap do |user|
          user.role_users.create!(role: create(:role, name: 'orders_only', permissions: %w[read_orders]), resource: store)
        end
      end
      let(:headers) do
        { 'Authorization' => "Bearer #{Spree::Api::V3::TestingSupport.generate_jwt(staffer, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN)}" }
      end

      it 'is denied with the products permission named' do
        get :index, params: { option_type_id: option_type.prefixed_id }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(json_response.dig('error', 'details', 'required_permission')).to eq('read_products')
      end
    end
  end

  context 'when the parent has translatable children (option type → values)' do
    let!(:option_type) { create(:option_type, name: 'size', presentation: 'Size') }
    let!(:option_value) { create(:option_value, name: 'small', presentation: 'Small', option_type: option_type) }

    it 'nests each option value matrix under the option type translations' do
      Mobility.with_locale(:de) { option_value.update!(presentation: 'Klein') }

      get :index, params: { option_type_id: option_type.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      data = json_response['data']
      expect(data['resource_type']).to eq('option_type')
      expect(data['fields'].first['key']).to eq('label')

      child = data['children'].find { |c| c['resource_id'] == option_value.prefixed_id }
      expect(child['resource_type']).to eq('option_value')
      expect(child['translations']['de']['label']).to eq('Klein')
    end
  end

  context 'when the parent is a category' do
    # Taxonomy-backed on purpose: the last example covers the pre-upgrade
    # fallback, where store_id is NULL and the store resolves via the taxonomy.
    let!(:taxonomy) { create(:taxonomy, store: store) }
    let!(:category) { create(:category, name: 'Clothing', taxonomy: taxonomy, parent: taxonomy.root) }

    it 'returns the translation matrix for the category' do
      get :index, params: { category_id: category.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      data = json_response['data']
      expect(data['resource_type']).to eq('category')
      expect(data['resource_id']).to eq(category.prefixed_id)
    end

    it 'works for a top-level taxonomy root category' do
      get :index, params: { category_id: taxonomy.root.prefixed_id }, as: :json
      expect(response).to have_http_status(:ok)
    end
  end

  context 'when the parent param resolves to nothing translatable' do
    it 'has no route for a non-translatable parent' do
      # tax_categories are not in Spree.translatable_resources and the
      # :translatable concern is not mounted on them, so no nested
      # translations route exists — the resource cannot be translated at all.
      expect {
        get :index, params: { tax_category_id: 'tax_1' }, as: :json
      }.to raise_error(ActionController::UrlGenerationError)
    end
  end
end
