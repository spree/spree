class String
  def articleize
    if split.first == 'User'
      "a #{self}"
    else
      %w(a e i o u).include?(self[0].downcase) ? "an #{self}" : "a #{self}"
    end
  end
end

shared_context 'Platform API v2' do
  let(:store) { Spree::Store.default }
  let(:admin_app) { Spree::OauthApplication.find_or_create_by!(name: 'Admin Panel', scopes: 'admin', redirect_uri: '') }
  let(:read_app) { Spree::OauthApplication.find_or_create_by!(name: 'Read App', scopes: 'read', redirect_uri: '') }
  let(:oauth_token) do
    Spree::OauthAccessToken.create!(
      application_id: admin_app.id,
      scopes: admin_app.scopes
    )
  end
  let(:read_oauth_token) do
    Spree::OauthAccessToken.create!(
      application_id: read_app.id,
      scopes: read_app.scopes
    )
  end
  let(:user_oauth_token) do
    Spree::OauthAccessToken.create!(
      resource_owner: user,
      application_id: admin_app.id,
      scopes: admin_app.scopes
    )
  end
  let(:user_oauth_token_without_app) do
    Spree::OauthAccessToken.create!(
      resource_owner: user,
      scopes: 'admin'
    )
  end

  let(:valid_authorization) { "Bearer #{oauth_token.token}" }
  let(:valid_read_authorization) { "Bearer #{read_oauth_token.token}" }
  let(:valid_user_authorization) { "Bearer #{user_oauth_token.token}" }
  let(:valid_user_authorization_without_app) { "Bearer #{user_oauth_token_without_app.token}" }
  let(:bogus_authorization) { "Bearer #{::Base64.strict_encode64('bogus:bogus')}" }

  let(:Authorization) { valid_authorization }
end

shared_context 'jsonapi pagination' do
  let(:page) { 1 }
  let(:per_page) { '' }
  parameter name: :page, in: :query, type: :integer, example: 1
  parameter name: :per_page, in: :query, type: :integer, example: 50
end

JSON_API_INCLUDES_DESCRIPTION = 'Select which associated resources you would like to fetch'\
                                ', see: <a href="https://jsonapi.org/format/#fetching-includes">'\
                                'https://jsonapi.org/format/#fetching-includes</a>'.freeze
JSON_API_FILTER_DESCRIPTION = ''

def json_api_include_parameter(example = '')
  let(:include) { nil }
  parameter name: :include, in: :query, type: :string, description: JSON_API_INCLUDES_DESCRIPTION, example: example
end

def json_api_filter_parameter(examples = [])
  examples.each do |api_filter|
    name = api_filter[:name].to_sym
    example = api_filter[:example]
    let(name) { nil }

    parameter name: name, in: :query, type: :string, description: JSON_API_FILTER_DESCRIPTION, example: example
  end
end

shared_examples 'authentication failed' do
  response '401', 'Authentication Failed' do
    let(:Authorization) { bogus_authorization }
    schema '$ref' => '#/components/schemas/error'
    run_test!
  end
end

shared_examples 'record not found' do
  response '404', 'Record not found' do
    let(:id) { 'invalid' }
    schema '$ref' => '#/components/schemas/error'
    run_test!
  end
end

shared_examples 'record found' do
  response '200', 'Record found' do
    schema '$ref' => '#/components/schemas/resource'
    run_test!
  end
end

shared_examples 'record deleted' do
  response '204', 'Record deleted' do
    run_test!
  end
end

shared_examples 'records returned' do
  response '200', 'Records returned' do
    schema '$ref' => '#/components/schemas/resources_list'
    run_test!
  end
end

shared_examples 'record created' do
  response '201', 'Record created' do
    schema '$ref' => '#/components/schemas/resource'
    run_test!
  end
end

shared_examples 'record updated' do
  response '200', 'Record updated' do
    schema '$ref' => '#/components/schemas/resource'
    run_test!
  end
end

shared_examples 'invalid request' do |param_name|
  response '422', 'Invalid request' do
    let(param_name) { invalid_param_value }
    schema '$ref' => '#/components/schemas/validation_errors'
    run_test!
  end
end

# index action
shared_examples 'GET records list' do |resource_name, **options|
  endpoint_name = options[:custom_endpoint_name] || resource_name

  get "Return a list of #{endpoint_name.pluralize}" do
    tags endpoint_name.pluralize
    security [ bearer_auth: [] ]
    description "Returns a list of #{endpoint_name.pluralize}"
    operationId "#{resource_name.parameterize.pluralize.to_sym}-list"
    include_context 'jsonapi pagination'
    json_api_include_parameter(options[:include_example]) unless options[:include_example].nil?
    json_api_filter_parameter(options[:filter_examples]) unless options[:filter_examples].nil?

    before { records_list }

    it_behaves_like 'records returned'
    it_behaves_like 'authentication failed'
  end
end

# show
shared_examples 'GET record' do |resource_name, **options|
  endpoint_name = options[:custom_endpoint_name] || resource_name

  get "Return #{endpoint_name.articleize}" do
    tags endpoint_name.pluralize
    security [ bearer_auth: [] ]
    description "Returns #{endpoint_name.articleize}"
    operationId "show-#{resource_name.parameterize.to_sym}"
    parameter name: :id, in: :path, type: :string
    json_api_include_parameter(options[:include_example]) unless options[:include_example].nil?

    it_behaves_like 'record found'
    it_behaves_like 'record not found'
    it_behaves_like 'authentication failed'
  end
end

# create
shared_examples 'POST create record' do |resource_name, **options|
  custom_create_params = options[:custom_create_params] || nil
  endpoint_name = options[:custom_endpoint_name] || resource_name
  param_name = resource_name.parameterize(separator: '_').to_sym
  consumes_kind = options[:consumes_kind] || 'application/json'
  request_data_type = case consumes_kind
                      when 'multipart/form-data'
                        :formData
                      else
                        :body
                      end

  post "Create #{endpoint_name.articleize}" do
    tags endpoint_name.pluralize
    consumes consumes_kind
    security [ bearer_auth: [] ]
    description "Creates #{endpoint_name.articleize}"
    operationId "create-#{resource_name.parameterize.to_sym}"
    if custom_create_params
      parameter name: param_name, in: request_data_type, schema: custom_create_params
    else
      parameter name: param_name, in: request_data_type, schema: { '$ref' => "#/components/schemas/create_#{param_name}_params" }
    end
    json_api_include_parameter(options[:include_example]) unless options[:include_example].nil?

    let(param_name) { valid_create_param_value }

    it_behaves_like 'record created'
    it_behaves_like 'invalid request', param_name unless options[:skip_invalid_params] == true
  end
end

# update
shared_examples 'PATCH update record' do |resource_name, **options|
  custom_update_params = options[:custom_update_params] || nil
  endpoint_name = options[:custom_endpoint_name] || resource_name
  param_name = resource_name.parameterize(separator: '_').to_sym
  consumes_kind = options[:consumes_kind] || 'application/json'
  request_data_type = case consumes_kind
                      when 'multipart/form-data'
                        :formData
                      else
                        :body
                      end

  patch "Update #{endpoint_name.articleize}" do
    tags endpoint_name.pluralize
    security [ bearer_auth: [] ]
    description "Updates #{endpoint_name.articleize}"
    operationId "update-#{resource_name.parameterize.to_sym}"
    consumes consumes_kind
    parameter name: :id, in: :path, type: :string
    if custom_update_params
      parameter name: param_name, in: request_data_type, schema: custom_update_params
    else
      parameter name: param_name, in: request_data_type, schema: { '$ref' => "#/components/schemas/update_#{param_name}_params" }
    end
    json_api_include_parameter(options[:include_example]) unless options[:include_example].nil?

    let(param_name) { valid_update_param_value }

    it_behaves_like 'record updated'
    it_behaves_like 'invalid request', param_name unless options[:skip_invalid_params] == true
    it_behaves_like 'record not found'
    it_behaves_like 'authentication failed'
  end
end

# destroy
shared_examples 'DELETE record' do |resource_name, **options|
  endpoint_name = options[:custom_endpoint_name] || resource_name

  delete "Delete #{endpoint_name.articleize}" do
    tags endpoint_name.pluralize
    security [ bearer_auth: [] ]
    description "Deletes #{endpoint_name.articleize}"
    operationId "delete-#{resource_name.parameterize.to_sym}"
    parameter name: :id, in: :path, type: :string

    it_behaves_like 'record deleted'
    it_behaves_like 'record not found'
    it_behaves_like 'authentication failed'
  end
end

shared_examples 'CRUD examples' do |resource_name, **options|
  resource_path = resource_name.parameterize(separator: '_').pluralize

  path "/api/v2/platform/#{resource_path}" do
    include_examples 'GET records list', resource_name, options
    include_examples 'POST create record', resource_name, options
  end

  path "/api/v2/platform/#{resource_path}/{id}" do
    include_examples 'GET record', resource_name, options
    include_examples 'PATCH update record', resource_name, options
    include_examples 'DELETE record', resource_name, options
  end
end
