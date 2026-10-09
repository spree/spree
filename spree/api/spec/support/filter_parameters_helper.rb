# Documents a list endpoint's filters from the model allowlists, so no
# integration spec lists `q[...]` parameters by hand.
#
#   path '/api/v3/admin/orders' do
#     get 'List orders' do
#       filter_parameters_for
#
# Adds one `q` parameter and the operation's `x-spree-filters` extension
# (root table and sortable fields), and registers every table the endpoint's
# filters reach under the spec's `components.x-spree-filter-tables`, which is
# what the SDK filter types are generated from.
module FilterParametersHelper
  FILTER_TABLES_KEY = :'x-spree-filter-tables'
  FILTER_PREDICATES_KEY = :'x-spree-filter-predicates'

  # @param controller_class [Class, nil] the controller serving the list;
  #   resolved from the path when omitted
  # @param notes [String, nil] what a reader needs beyond the table, such as
  #   what a scope's argument means
  def filter_parameters_for(controller_class = nil, notes: nil)
    endpoint = Spree::Api::V3::FilterTable.for(controller_class || filter_controller_for_path)
    description = 'Filters, as `q[<attribute>_<predicate>]=value`. The attributes, predicates, ' \
                  'associations and scopes this endpoint accepts are listed in `x-spree-filters`.'

    parameter name: :q, in: :query, required: false, style: :deepObject, explode: true,
              schema: { type: :object, additionalProperties: true },
              description: [description, notes].compact.join("\n\n")

    metadata[:operation][:'x-spree-filters'] = endpoint.to_h
    register_filter_tables(endpoint.tables)
  end

  private

  def filter_controller_for_path
    path = metadata[:path_item][:template].gsub(/\{[^}]+\}/, 'x1')
    route = Rails.application.routes.recognize_path(path, method: :get)
    "#{route[:controller]}_controller".camelize.constantize
  end

  def register_filter_tables(tables)
    spec = RSpec.configuration.openapi_specs.fetch(metadata[:openapi_spec] || metadata[:swagger_doc])
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
