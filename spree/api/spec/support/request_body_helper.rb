# Documents a write endpoint's request body from the controller's
# `request_params` declaration, so no integration spec describes a body by hand.
#
#   path '/api/v3/admin/products' do
#     post 'Create a product' do
#       request_body_for
#
# The body references the `<Resource>CreateParams` / `<Resource>UpdateParams`
# component, registered with every shared shape it uses under the spec's
# `components.schemas`. The SDK request types are generated from those
# components.
module RequestBodyHelper
  # @param action [Symbol, nil] the controller action; read from the route
  #   when omitted
  # @param controller [Class, nil] resolved from the path when omitted
  # @param required [Boolean] false for an endpoint that accepts no body
  def request_body_for(action = nil, controller: nil, required: true)
    route = request_body_route
    action ||= route[:action].to_sym
    controller ||= "#{route[:controller]}_controller".camelize.constantize
    schema = controller.request_params_schema(action)
    raise "#{controller.name} does not declare request_params for #{action}" unless schema

    name = schema.component_name(action)
    register_request_schema(name, schema.json_schema(action.in?(%i[create update]) ? action : nil))
    schema.shapes.each { |shape| register_request_schema(shape.name, shape.json_schema) }
    schema.code_lists.each { |list_name, definition| register_request_schema(list_name, definition) }

    parameter name: :body, in: :body, required: required, schema: { '$ref': "#/components/schemas/#{name}" }
  end

  private

  def request_body_route
    path = metadata[:path_item][:template].gsub(/\{[^}]+\}/, 'x1')
    Rails.application.routes.recognize_path(path, method: metadata[:operation][:verb])
  end

  def register_request_schema(name, definition)
    spec = RSpec.configuration.openapi_specs.fetch(metadata[:openapi_spec] || metadata[:swagger_doc])
    schemas = (spec[:components] ||= {})[:schemas] ||= {}
    definition = definition.deep_stringify_keys

    if schemas.key?(name) && schemas[name].deep_stringify_keys != definition
      raise "Two request schemas are named #{name}; name one of the request_params declarations or shapes differently"
    end

    schemas[name] = definition
    # Request schemas follow the response ones, sorted, so the written spec
    # does not depend on the order specs ran in.
    request, response = schemas.partition { |key, _| key.to_s.end_with?('Params') }
    spec[:components][:schemas] = response.to_h.merge(request.sort_by { |key, _| key.to_s }.to_h)
  end
end

RSpec.configure do |config|
  config.extend RequestBodyHelper, type: :request
end
