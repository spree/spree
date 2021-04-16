class String
  def articleize
    %w(a e i o u).include?(self[0].downcase) ? "an #{self}" : "a #{self}"
  end
end

shared_context 'Platform API v2' do
  let(:admin_app) { Doorkeeper::Application.find_or_create_by!(name: 'Admin Panel', scopes: 'admin', redirect_uri: '') }
  let(:read_app) { Doorkeeper::Application.find_or_create_by!(name: 'Read App', scopes: 'read', redirect_uri: '') }
  let(:oauth_token) do
    Doorkeeper::AccessToken.create!(
      application_id: admin_app.id,
      scopes: admin_app.scopes
    )
  end
  let(:read_oauth_token) do
    Doorkeeper::AccessToken.create!(
      application_id: read_app.id,
      scopes: read_app.scopes
    )
  end
  let(:user_oauth_token) do
    Doorkeeper::AccessToken.create!(
      resource_owner_id: user.id,
      application_id: admin_app.id,
      scopes: admin_app.scopes
    )
  end

  let(:valid_authorization) { "Bearer #{oauth_token.token}" }
  let(:valid_read_authorization) { "Bearer #{read_oauth_token.token}" }
  let(:valid_user_authorization) { "Bearer #{user_oauth_token.token}" }
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
  parameter name: :include, in: :query, type: :string, descripton: JSON_API_INCLUDES_DESCRIPTION, example: example
end

def json_api_filter_parameter(example = '')
  let(:filter) { nil }
  parameter name: :filter, in: :query, type: :string, descripton: JSON_API_FILTER_DESCRIPTION, example: example
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
  response '201', 'record created' do
    schema '$ref' => '#/components/schemas/resource'
    run_test!
  end
end

shared_examples 'record updated' do
  response '200', 'record updated' do
    schema '$ref' => '#/components/schemas/resource'
    run_test!
  end
end

shared_examples 'invalid request' do |param_name|
  response '422', 'invalid request' do
    let(param_name) { invalid_param_value }
    schema '$ref' => '#/components/schemas/validation_errors'
    run_test!
  end
end

# index action
shared_examples 'GET records list' do |resource_name, include_example, filter_example|
  get "Returns a list of #{resource_name.pluralize}" do
    tags resource_name.pluralize
    security [ bearer_auth: [] ]
    include_context 'jsonapi pagination'
    json_api_include_parameter(include_example)
    json_api_filter_parameter(filter_example)

    before { records_list }

    it_behaves_like 'records returned'
    it_behaves_like 'authentication failed'
  end
end

# show
shared_examples 'GET record' do |resource_name, include_example|
  get "Returns #{resource_name.articleize}" do
    tags resource_name.pluralize
    security [ bearer_auth: [] ]
    parameter name: :id, in: :path, type: :string
    json_api_include_parameter(include_example)

    it_behaves_like 'record found'
    it_behaves_like 'record not found'
    it_behaves_like 'authentication failed'
  end
end

# create
shared_examples 'POST create record' do |resource_name, include_example|
  param_name = resource_name.parameterize.to_sym

  post "Creates #{resource_name.articleize}" do
    tags resource_name.pluralize
    consumes 'application/json'
    security [ bearer_auth: [] ]
    parameter name: param_name, in: :body, schema: { '$ref' => "#/components/schemas/#{param_name}_params" }
    json_api_include_parameter(include_example)

    let(param_name) { valid_create_param_value }

    it_behaves_like 'record created'
    it_behaves_like 'invalid request', param_name
  end
end

# update
shared_examples 'PUT update record' do |resource_name, include_example|
  param_name = resource_name.parameterize.to_sym

  put "Updates #{resource_name.articleize}" do
    tags resource_name.pluralize
    security [ bearer_auth: [] ]
    consumes 'application/json'
    parameter name: :id, in: :path, type: :string
    parameter name: param_name, in: :body, schema: { '$ref' => "#/components/schemas/#{param_name}_params" }
    json_api_include_parameter(include_example)

    let(param_name) { valid_update_param_value }

    it_behaves_like 'record updated'
    it_behaves_like 'invalid request', param_name
    it_behaves_like 'record not found'
    it_behaves_like 'authentication failed'
  end
end

# destroy
shared_examples 'DELETE record' do |resource_name|
  delete "Deletes #{resource_name.articleize}" do
    tags resource_name.pluralize
    security [ bearer_auth: [] ]
    parameter name: :id, in: :path, type: :string

    it_behaves_like 'record deleted'
    it_behaves_like 'record not found'
    it_behaves_like 'authentication failed'
  end
end

shared_examples 'CRUD examples' do |resource_name, include_example, filter_example|
  resource_path = resource_name.pluralize.parameterize

  path "/api/v2/platform/#{resource_path}" do
    include_examples 'GET records list', resource_name, include_example, filter_example
    include_examples 'POST create record', resource_name, include_example
  end

  path "/api/v2/platform/#{resource_path}/{id}" do
    include_examples 'GET record', resource_name, include_example
    include_examples 'PUT update record', resource_name, include_example
    include_examples 'DELETE record', resource_name
  end
end
