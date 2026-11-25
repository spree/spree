require 'spec_helper'
require 'spree/api/testing_support/openapi'

RSpec.describe Spree::Api::TestingSupport::ResponseSchema do
  let(:document) { { components: { schemas: { 'Order' => {} } } } }

  def controller(klass, action)
    klass.new.tap { |controller| allow(controller).to receive(:action_name).and_return(action) }
  end

  it 'documents a list with the paginated schema of the serializer its controller renders' do
    schema = described_class.for(controller(Spree::Api::V3::Admin::OrdersController, 'index'), document)

    expect(schema).to eq(Spree::Api::OpenAPI::SchemaHelper.paginated('Order'))
  end

  it 'documents every other action with the resource itself' do
    schema = described_class.for(controller(Spree::Api::V3::Admin::OrdersController, 'approve'), document)

    expect(schema).to eq('$ref' => '#/components/schemas/Order')
  end

  it 'leaves a response alone when the document does not publish the serializer' do
    expect(described_class.for(controller(Spree::Api::V3::Admin::ProductsController, 'show'), document)).to be_nil
  end

  it 'leaves a response alone when its controller renders no serializer' do
    expect(described_class.for(controller(Spree::Api::V3::Admin::TagsController, 'index'), document)).to be_nil
  end

  # The reference page of an endpoint lists the fields of its response from the
  # schema; an example alone leaves that section empty.
  describe 'the API reference' do
    def json_responses(api)
      document = YAML.load_file(Rails.root.join("../../../../docs/api-reference/#{api}.yaml"))

      document['paths'].flat_map do |path, operations|
        operations.slice('get', 'post', 'put', 'patch', 'delete').flat_map do |verb, operation|
          operation['responses'].filter_map do |code, response|
            json = response.dig('content', 'application/json')
            ["#{verb.upcase} #{path} #{code}", json['schema']] if json && code.start_with?('2')
          end
        end
      end
    end

    %w[admin store seller].each do |api|
      it "gives every successful #{api} response a schema" do
        missing = json_responses(api).select { |_response, schema| schema.blank? }.map(&:first)

        expect(missing).to be_empty, "declare a `schema` in the integration spec's response block of:\n#{missing.join("\n")}"
      end

      # Two response blocks of one status are merged into one response, so a
      # block left to the default beside one that declares a schema would
      # publish both.
      it "gives no #{api} response two schemas" do
        merged = json_responses(api).select { |_response, schema| schema&.key?('$ref') && schema.size > 1 }.map(&:first)

        expect(merged).to be_empty, "declare the same `schema` in every response block of:\n#{merged.join("\n")}"
      end
    end
  end
end
