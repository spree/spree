require 'spec_helper'
require 'spree/api/testing_support/openapi'

RSpec.describe Spree::Api::TestingSupport::Openapi do
  # The settings rswag adds to RSpec's configuration, and what the helpers are
  # registered with, recorded rather than applied to the running suite.
  let(:config_class) do
    Class.new do
      attr_accessor :openapi_root, :openapi_specs, :openapi_format
      attr_reader :helpers

      def extend(helper, **)
        (@helpers ||= []) << helper
      end

      def include_context(*); end
    end
  end
  let(:config) { config_class.new }
  let(:engine) { Spree::Api::Engine }

  it "writes the extension's admin document" do
    described_class.configure(config, engine: engine, title: 'Quotes Admin API')

    expect(config.openapi_specs.keys).to eq(['openapi/admin.yaml'])
    expect(config.openapi_specs['openapi/admin.yaml'][:info][:title]).to eq('Quotes Admin API')
    expect(config.openapi_root).to eq(engine.root.to_s)
  end

  it 'also writes a store document, after the admin one, for an extension with Store API endpoints' do
    described_class.configure(config, engine: engine, title: 'Quotes Admin API', store_title: 'Quotes Store API')

    expect(config.openapi_specs.keys).to eq(['openapi/admin.yaml', 'openapi/store.yaml'])
    store = config.openapi_specs['openapi/store.yaml']
    expect(store[:info][:title]).to eq('Quotes Store API')
    expect(store.dig(:components, :securitySchemes, :api_key, :description)).to eq('Publishable API key for store access')
  end

  it "documents list filters in the extension's specs" do
    described_class.configure(config, engine: engine, title: 'Quotes Admin API')

    expect(config.helpers).to include(Spree::Api::TestingSupport::FilterParameters)
  end
end
