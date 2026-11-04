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

  # configure records the engine for the whole process; Spree's own documents
  # are written with none.
  after { described_class.engine = nil }
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

  describe 'filter tables' do
    # An operation in the extension's store document, as rswag hands it to
    # filter_parameters_for.
    let(:operation) do
      Class.new do
        include Spree::Api::TestingSupport::FilterParameters

        def metadata
          { openapi_spec: 'openapi/store.yaml' }
        end
      end.new
    end

    # Spree::Order is defined in spree_core, so it is the extension's own
    # table when the engine is spree_core, and core's when it is spree_api.
    let(:order_table) { double(model: Spree::Order, to_h: { attributes: { number: 'text' } }) }

    def register(engine, tables)
      described_class.configure(config, engine: engine, title: 'Quotes Admin API', store_title: 'Quotes Store API')
      allow(RSpec.configuration).to receive(:openapi_specs).and_return(config.openapi_specs)
      operation.send(:register_filter_tables, tables)
      config.openapi_specs['openapi/store.yaml'][:components]
    end

    it 'registers them in the document the operation names' do
      store = register(Spree::Core::Engine, 'Order' => order_table)

      expect(store[:'x-spree-filter-tables']).to eq('Order' => { attributes: { number: 'text' } })
      expect(store[:'x-spree-filter-predicates']).to eq(Spree::Api::V3::FilterPredicates::BY_KIND)
      expect(config.openapi_specs['openapi/admin.yaml'][:components]).not_to have_key(:'x-spree-filter-tables')
    end

    it "leaves out the tables of models the engine doesn't define, which core's document has" do
      store = register(Spree::Api::Engine, 'Order' => order_table)

      expect(store[:'x-spree-filter-tables']).to eq({})
    end
  end
end
