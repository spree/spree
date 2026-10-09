# Documents a list endpoint's filters from the model allowlists, so no
# integration spec lists `q[...]` parameters by hand.
#
#   path '/api/v3/admin/orders' do
#     get 'List orders' do
#       filter_parameters_for search: 'Order number, purchase order or customer name'
#
# Adds `q[search]` first and the endpoint's other scopes as named query
# parameters, one `q` parameter for attribute filters, the attribute table
# above the endpoint (`x-mint.content`), and the machine-readable
# `x-spree-filters` extension. Every table the filters reach is registered
# under the spec's `components.x-spree-filter-tables`, which is what the SDK
# filter types are generated from.
module FilterParametersHelper
  FILTER_TABLES_KEY = :'x-spree-filter-tables'
  FILTER_PREDICATES_KEY = :'x-spree-filter-predicates'
  # What `q[search]` matches on models whose search is written by hand rather
  # than declared with `search_by` (which describes itself).
  SEARCH_DESCRIPTIONS = {
    'Product' => 'Matches product name or variant SKU (partial, case-insensitive), and the store\'s searchable custom fields.',
    'Variant' => 'Matches SKU, option value or product name (partial, case-insensitive; at least three characters).',
    'Price' => 'Matches the variant\'s SKU, option value or product name, as variant search does.',
    'Customer' => 'Matches email, first name, last name or full name (partial, case-insensitive).',
    'Order' => 'Matches order number or purchase order number (partial), the billing first or last name, or the exact email.'
  }.freeze

  QUERYING_PAGES = {
    'api-reference/store.yaml' => '/api-reference/store-api/querying#which-filters-an-endpoint-accepts'
  }.freeze

  # @param controller_class [Class, nil] the controller serving the list;
  #   resolved from the path when omitted
  # @param search [String, nil] what `q[search]` matches, required when the
  #   model's search is not declared with `search_by`
  # @param scopes [Hash{Symbol => String}] descriptions of other scopes
  def filter_parameters_for(controller_class = nil, search: nil, scopes: {})
    endpoint = Spree::Api::V3::FilterTable.for(controller_class || filter_controller_for_path)
    docs = Spree::Api::OpenAPI::FilterDocumentation.new(
      endpoint, search: search || SEARCH_DESCRIPTIONS[endpoint.table.name], scopes: scopes,
      querying_path: QUERYING_PAGES.fetch(spec_name, '/api-reference/admin-api/querying#which-filters-an-endpoint-accepts')
    )

    parameter name: :q, in: :query, required: false, style: :deepObject, explode: true,
              schema: { type: :object, additionalProperties: true },
              description: 'Attribute filters, as `q[<attribute>_<predicate>]=value`. See Filters above for the list.'
    insert_before_query_parameters(docs.parameters)

    metadata[:operation][:'x-mint'] = (metadata[:operation][:'x-mint'] || {}).merge(content: docs.content)
    metadata[:operation][:'x-spree-filters'] = endpoint.to_h
    register_filter_tables(endpoint.tables)
  end

  private

  def filter_controller_for_path
    path = metadata[:path_item][:template].gsub(/\{[^}]+\}/, 'x1')
    route = Rails.application.routes.recognize_path(path, method: :get)
    "#{route[:controller]}_controller".camelize.constantize
  end

  def spec_name
    metadata[:openapi_spec] || metadata[:swagger_doc]
  end

  # `q[search]` and the scopes go ahead of `page`, `sort` and the rest, so the
  # filter a reader reaches for first is the first one listed.
  def insert_before_query_parameters(parameters)
    existing = metadata[:operation][:parameters] ||= []
    index = existing.index { |parameter| parameter[:in] == :query } || existing.size
    existing.insert(index, *parameters)
  end

  def register_filter_tables(tables)
    spec = RSpec.configuration.openapi_specs.fetch(spec_name)
    components = spec[:components] ||= {}
    registered = components[FILTER_TABLES_KEY] || {}

    tables.each do |name, table|
      definition = table.to_h
      if registered.key?(name) && registered[name] != definition
        raise "Two filter tables are named #{name} in #{metadata[:swagger_doc]}; give one of the models a distinct api_type"
      end

      registered[name] = definition
    end

    # Sorted so the written spec does not depend on the order specs ran in.
    components[FILTER_TABLES_KEY] = registered.sort.to_h
    components[FILTER_PREDICATES_KEY] = Spree::Api::V3::FilterPredicates::BY_KIND
  end
end

RSpec.configure do |config|
  config.extend FilterParametersHelper, type: :request
end
