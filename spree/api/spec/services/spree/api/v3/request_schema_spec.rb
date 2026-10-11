require 'spec_helper'

RSpec.describe Spree::Api::V3::RequestSchema do
  let(:price) do
    described_class.shape('TestPriceParams') do
      string :currency, required: true
      decimal :amount, required: true
    end
  end

  let(:schema) do
    price_shape = price
    described_class.new(:widget) do
      string :name, required: :create, description: 'The name.'
      string :code, required: true
      string :kind, enum: %w[small large], only: :create
      string :tags, array: true
      id :tax_category_id, nullable: true
      object :metadata
      object :prices, array: true, shape: price_shape
      object :main_price, shape: price_shape, description: 'The main price.'
      object :options, array: true do
        string :name, :value, required: true
      end
      any :value
      object :external_references, permit: false
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

  it 'rejects a field declared twice' do
    expect { described_class.new { string :name, :name } }.to raise_error(ArgumentError, /declared twice/)
  end

  it 'rejects an array of any-key hashes, which Rails cannot permit' do
    expect { described_class.new { object :rows, array: true } }.to raise_error(ArgumentError, /needs a shape/)
  end

  describe 'controller declarations' do
    it 'permits every field a product write accepted before' do
      controller = Spree::Api::V3::Admin::ProductsController.new
      allow(controller).to receive(:action_name).and_return('create')

      expect(controller.send(:resource_permitted_attributes)).to include(
        :name, :status, :promotionable,
        { metadata: {} },
        { variants: a_collection_including(:sku, :preorder_ships_at, { stock_levels: [:id, :stock_location_id, :count_on_hand, :backorderable] }) }
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
end
