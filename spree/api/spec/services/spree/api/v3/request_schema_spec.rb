require 'spec_helper'

RSpec.describe Spree::Api::V3::RequestSchema do
  let(:price) do
    described_class.shape('TestPriceParams') do |schema|
      schema.attribute :currency, :string, required: true
      schema.attribute :amount, :decimal, required: true
    end
  end

  let(:schema) do
    price_shape = price
    described_class.new(:widget) do |schema|
      schema.attribute :name, :string, required: true, on: :create, description: 'The name.'
      schema.attribute :code, :string, required: true
      schema.attribute :kind, :string, choices: %w[small large], only: :create
      schema.attribute :tags, :array, of: :string
      schema.attribute :tax_category_id, :id, nullable: true
      schema.attribute :metadata, :hash
      schema.attribute :prices, :array, of: price_shape
      schema.attribute :main_price, :object, shape: price_shape, description: 'The main price.'
      schema.attribute :options, :array do |option|
        option.attribute :name, :string, required: true
        option.attribute :value, :string, required: true
      end
      schema.attribute :value, :any
      schema.attribute :external_references, :hash, permit: false
    end
  end

  describe '#permit_list' do
    it 'lists scalars first, then lists, hashes and nested shapes' do
      expect(schema.permit_list(:create)).to eq([
        :name, :code, :kind, :tax_category_id, :value,
        { tags: [] },
        { metadata: {} },
        { prices: [:currency, :amount] },
        { main_price: [:currency, :amount] },
        { options: [:name, :value] },
        { value: [] }, { value: {} }
      ])
    end

    it 'leaves out fields accepted on the other action only' do
      expect(schema.permit_list(:update)).not_to include(:kind)
    end

    it 'leaves out fields the controller reads itself' do
      expect(schema.permit_list(:create).flat_map { |entry| entry.is_a?(Hash) ? entry.keys : entry }).
        not_to include(:external_references)
    end

    it 'permits the declared keys from a request' do
      params = ActionController::Parameters.new(
        name: 'Widget', kind: 'small', tags: %w[a b], metadata: { 'any' => 'thing' },
        prices: [{ currency: 'USD', amount: '1.00', cost: '2' }], value: { 'nested' => [1] }, admin: true
      )

      expect(params.permit(*schema.permit_list(:create)).to_h).to eq(
        'name' => 'Widget', 'kind' => 'small', 'tags' => %w[a b], 'metadata' => { 'any' => 'thing' },
        'prices' => [{ 'currency' => 'USD', 'amount' => '1.00' }], 'value' => { 'nested' => [1] }
      )
    end
  end

  describe '#json_schema' do
    subject(:json) { schema.json_schema(:create) }

    it 'requires create-only and always-required fields when creating' do
      expect(json[:required]).to eq(%w[name code])
      expect(schema.json_schema(:update)[:required]).to eq(%w[code])
    end

    it 'describes each kind of value' do
      expect(json[:properties]).to include(
        name: { type: :string, description: 'The name.' },
        kind: { type: :string, enum: %w[small large] },
        tags: { type: :array, items: { type: :string } },
        tax_category_id: { type: :string, nullable: true },
        metadata: { type: :object, additionalProperties: true },
        value: {},
        external_references: { type: :object, additionalProperties: true }
      )
    end

    it 'references shapes, wrapping a described reference' do
      expect(json[:properties][:prices]).to eq(type: :array, items: { '$ref': '#/components/schemas/TestPriceParams' })
      expect(json[:properties][:main_price]).to eq(
        allOf: [{ '$ref': '#/components/schemas/TestPriceParams' }], description: 'The main price.'
      )
    end

    it 'inlines an anonymous nested object' do
      expect(json[:properties][:options]).to eq(
        type: :array,
        items: { type: :object, properties: { name: { type: :string }, value: { type: :string } }, required: %w[name value] }
      )
    end

    it 'flags a deprecated field and says what replaces it' do
      schema = described_class.new { |schema| schema.attribute :country_iso, :string,
                                       description: 'The old name.',
                                       deprecated: 'Use `country_code`.' }

      expect(schema.json_schema[:properties][:country_iso]).to eq(
        type: :string, deprecated: true, description: 'The old name. Deprecated: Use `country_code`.'
      )
      expect(schema.permit_list).to eq([:country_iso])
    end

    it 'references the shared ISO code lists and publishes them' do
      schema = described_class.new do |schema|
        schema.attribute :country_code, :country
        schema.attribute :currencies, :array, of: :currency
      end

      expect(schema.json_schema[:properties]).to eq(
        country_code: { '$ref': '#/components/schemas/CountryCode' },
        currencies: { type: :array, items: { '$ref': '#/components/schemas/CurrencyCode' } }
      )
      expect(schema.code_lists['CountryCode'][:enum]).to include('US', 'DE')
      expect(schema.code_lists['CountryCode'][:enum]).not_to include('AQ')
      expect(schema.code_lists['CurrencyCode'][:enum]).to include('USD', 'EUR')
      expect(schema.permit_list).to eq([:country_code, { currencies: [] }])
    end

    it 'sends decimals as canonical strings' do
      expect(price.json_schema[:properties][:amount]).to include(type: :string, format: :decimal)
    end
  end

  describe '#component_name' do
    it 'names a resource schema per action' do
      expect(schema.component_name(:create)).to eq('WidgetCreateParams')
      expect(schema.component_name(:update)).to eq('WidgetUpdateParams')
    end

    it 'keeps a name that already ends in Params' do
      expect(described_class.new('WidgetArchiveParams').component_name(:create)).to eq('WidgetArchiveParams')
    end
  end

  describe '#shapes' do
    it 'lists every named shape once' do
      expect(schema.shapes).to eq([price])
    end
  end

  describe 'declared as a class' do
    let(:base) do
      Class.new(described_class) do
        publishes 'TestAddressParams'
        attribute :city, :string, required: true
      end
    end

    let(:extended) do
      parent = base
      Class.new(parent) { attribute :alternative_phone, :string }
    end

    it 'publishes the class fields under its name' do
      expect(base.definition.name).to eq('TestAddressParams')
      expect(base.definition.permit_list).to eq([:city])
    end

    it "starts a subclass from its parent's fields" do
      expect(extended.definition.permit_list).to eq(%i[city alternative_phone])
      expect(base.definition.permit_list).to eq([:city])
    end

    it 'can be used as a shape or included by its class' do
      shape = base
      schema = described_class.new(:widget) do |schema|
        schema.attribute :address, :object, shape: shape
        schema.include_attributes shape
      end

      expect(schema.shapes.map(&:name)).to eq(['TestAddressParams'])
      expect(schema.permit_list).to eq([:city, { address: [:city] }])
    end

    it 'refuses publishes after the fields' do
      expect { Class.new(described_class) { attribute :city, :string; publishes 'LateParams' } }.to raise_error(ArgumentError, /before the attributes/)
    end
  end

  it 'refuses a deprecation that names no replacement' do
    expect { described_class.new { |schema| schema.attribute :old, :string, deprecated: true } }.to raise_error(ArgumentError, /instead/)
  end

  describe 'declaring an attribute' do
    def declare(&block)
      described_class.new(&block)
    end

    it 'rejects an attribute declared twice' do
      expect do
        declare do |schema|
          schema.attribute :name, :string
          schema.attribute :name, :string
        end
      end.to raise_error(ArgumentError, /declared twice/)
    end

    it 'rejects an unknown type' do
      expect { declare { |schema| schema.attribute :name, :text } }.to raise_error(ArgumentError, /unknown type :text/)
    end

    it 'takes `on:` only to scope `required: true` to creating' do
      expect { declare { |schema| schema.attribute :name, :string, on: :create } }.to raise_error(ArgumentError, /on:/)
      expect { declare { |schema| schema.attribute :name, :string, required: true, on: :update } }.to raise_error(ArgumentError, /on:/)
    end

    it 'rejects a list of any-key hashes, which Rails cannot permit' do
      expect { declare { |schema| schema.attribute :rows, :array, of: :hash } }.to raise_error(ArgumentError, /needs `of:`/)
      expect { declare { |schema| schema.attribute :rows, :array, of: :any } }.to raise_error(ArgumentError, /cannot be permitted/)
      expect { declare { |schema| schema.attribute :rows, :array, of: :any, permit: false } }.not_to raise_error
    end

    it 'requires attributes taken from a shared set' do
      shared = described_class.new { |schema| schema.attribute :city, :string }
      schema = declare do |body|
        body.include_attributes shared
        body.require_attributes :city, on: :create
      end

      expect(schema.json_schema(:create)[:required]).to eq(['city'])
      expect(schema.json_schema(:update)).not_to have_key(:required)
      expect(shared.json_schema).not_to have_key(:required)
      expect { declare { |body| body.require_attributes :missing } }.to raise_error(ArgumentError, /not an attribute/)
    end

    it 'rejects an :object without a shape' do
      expect { declare { |schema| schema.attribute :address, :object } }.to raise_error(ArgumentError, /use :hash/)
    end
  end

  describe 'controller declarations' do
    it 'permits every field a product write accepted before' do
      controller = Spree::Api::V3::Admin::ProductsController.new
      allow(controller).to receive(:action_name).and_return('create')

      expect(controller.send(:resource_permitted_attributes)).to include(
        :name, :status, :promotionable,
        { metadata: {} },
        { variants: a_collection_including(:sku, :preorder_ships_at, { stock_levels: %i[stock_location_id count_on_hand backorderable] }) }
      )
    end
  end

  # The SDK request types are generated from the API reference, so a declared
  # body that no integration spec documents never reaches them. One documented
  # endpoint per body is enough: a body shared by several routes (custom fields
  # under each parent) publishes one type.
  describe 'every declared body' do
    it 'is published in the API reference' do
      references = {}
      missing = Spree::Core::Engine.routes.routes.filter_map do |route|
        controller_path = route.defaults[:controller].to_s
        next unless route.verb.to_s.in?(%w[POST PATCH PUT DELETE]) && controller_path.start_with?('spree/api/v3/')

        controller = "#{controller_path}_controller".camelize.safe_constantize
        schema = controller.try(:request_params_schema, route.defaults[:action])
        next unless schema

        api = controller_path.split('/')[3]
        spec = references[api] ||= YAML.load_file(Rails.root.join("../../../../docs/api-reference/#{api}.yaml"))
        name = schema.component_name(route.defaults[:action])
        next if spec.dig('components', 'schemas', name)

        path = route.path.spec.to_s.delete_suffix('(.:format)')
        "#{api}: #{name} (#{route.verb} #{path} → #{controller.name}##{route.defaults[:action]})"
      end

      expect(missing.uniq(&:split)).to be_empty,
                                       "add `request_body_for` to an integration spec of:\n#{missing.uniq { |line| line.split(' (').first }.join("\n")}"
    end
  end

  # A body the base create/update assigns straight onto the record must name
  # only what the model can take, or the request raises instead of saving.
  # Bodies a workflow or a custom action reads are the action's business.
  describe 'every attribute a model-backed write accepts' do
    it 'is writable on the model' do
      Rails.application.eager_load!
      routed = Spree::Core::Engine.routes.routes.to_set { |route| ["#{route.defaults[:controller]}_controller".camelize, route.defaults[:action].to_s] }
      base_actions = [Spree::Api::V3::ResourceController, Spree::Api::V3::Admin::ResourceController,
                      Spree::Api::V3::Seller::ResourceController, Spree::Api::V3::Store::ResourceController]

      unwritable = Spree::Api::V3::ResourceController.descendants.filter_map(&:name).sort.flat_map do |name|
        controller = name.constantize
        schema = controller.request_params_schemas[:resource]
        next [] unless schema

        instance = controller.new
        model = begin
          instance.send(:model_class)
        rescue NotImplementedError, NoMethodError # no model, or one picked per request
          nil
        end
        next [] unless model.is_a?(Class)

        %i[create update].flat_map do |action|
          next [] unless routed.include?([name, action.to_s])
          next [] unless base_actions.include?(controller.instance_method(action).owner)
          next [] if instance.send(:"#{action}_workflow")

          record = model.new
          schema.fields.each_value.filter_map do |field|
            next unless field.permit && field.accepted_on?(action)
            next if record.respond_to?("#{field.name}=")

            "#{name}##{action}: #{model.name} has no #{field.name}="
          end
        end
      end

      expect(unwritable).to be_empty, "declare these `only:` the other action, `permit: false`, or fix the name:\n#{unwritable.join("\n")}"
    end
  end
end
