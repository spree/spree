require 'spec_helper'

class ExtensionFieldsSpecWarrantySerializer
  include Alba::Resource

  attribute :months do |product|
    product.name.length
  end

  attribute :expand do
    params[:expand]
  end
end

RSpec.describe Spree::Api::ExtensionFields do
  let(:registry) { described_class.new }
  let(:store) { @default_store }
  let(:product) { create(:product, name: 'Widget', store: store) }
  let(:params) { { store: store, currency: 'USD' } }

  before { allow(Spree.api).to receive(:extension_fields).and_return(registry) }

  def render(serializer = Spree.api.admin_product_serializer, record = product, expand: nil)
    serializer.new(record, params: params.merge(expand: expand)).to_h
  end

  context 'with a field shown always' do
    before { registry.register(:admin_product_serializer, :warranty, serializer: ExtensionFieldsSpecWarrantySerializer) }

    it 'adds the field, written by its own serializer' do
      expect(render['warranty']).to include('months' => 6)
    end

    it 'drops a field once it is unregistered' do
      render
      registry.unregister(:admin_product_serializer, :warranty)

      expect(render).not_to have_key('warranty')
    end

    it 'leaves other serializers alone' do
      expect(render(Spree.api.product_serializer)).not_to have_key('warranty')
    end

    # The registration names the dependency, so a merchant's own serializer
    # cannot silently drop an extension's field.
    it 'follows a serializer the host app replaced' do
      replacement = Class.new(Spree::Api::V3::Admin::ProductSerializer)
      allow(Spree::Api::Dependencies).to receive(:admin_product_serializer_class).and_return(replacement)

      expect(render(replacement)['warranty']).to include('months' => 6)
    end

    it 'reads the value from the record when told how' do
      registry.register(:admin_product_serializer, :warranty_of_variant,
                        serializer: ExtensionFieldsSpecWarrantySerializer, value: ->(record) { record.default_variant.product })

      expect(render['warranty_of_variant']).to include('months' => 6)
    end
  end

  context 'with a field shown only when expanded' do
    before { registry.register(:admin_product_serializer, :warranty, serializer: 'ExtensionFieldsSpecWarrantySerializer', expand: true) }

    it 'is left out unless expanded' do
      expect(render).not_to have_key('warranty')
    end

    it 'is shown when expanded' do
      expect(render(expand: ['warranty'])['warranty']).to include('months' => 6, 'expand' => [])
    end

    it 'passes nested expands on to its serializer' do
      expect(render(expand: ['warranty.extended'])['warranty']).to include('expand' => ['extended'])
    end

    it 'is shown on every item of a list' do
      other = create(:product, name: 'Gadget', store: store)
      rows = Spree.api.admin_product_serializer.new([product, other], params: params.merge(expand: ['warranty'])).to_h

      expect(rows.map { |row| row['warranty']['months'] }).to eq([6, 6])
    end
  end

  it "never leaks a parent serializer's field into a subclass" do
    registry.register(:product_serializer, :warranty, serializer: ExtensionFieldsSpecWarrantySerializer)
    render(Spree.api.product_serializer)
    subclass = Class.new(Spree::Api::V3::ProductSerializer)

    expect(render(subclass)).not_to have_key('warranty')
  end

  describe '#register' do
    it 'refuses a name another extension took on that serializer' do
      registry.register(:admin_product_serializer, :warranty, serializer: ExtensionFieldsSpecWarrantySerializer)

      expect do
        registry.register(:admin_product_serializer, 'warranty', serializer: ExtensionFieldsSpecWarrantySerializer)
      end.to raise_error(described_class::DuplicateField, /warranty/)
    end

    it 'refuses a name the serializer already writes' do
      expect do
        registry.register(:admin_product_serializer, :name, serializer: ExtensionFieldsSpecWarrantySerializer)
      end.to raise_error(described_class::DuplicateField)
    end

    it 'allows the same name on another serializer' do
      registry.register(:admin_product_serializer, :warranty, serializer: ExtensionFieldsSpecWarrantySerializer)

      expect do
        registry.register(:seller_product_serializer, :warranty, serializer: ExtensionFieldsSpecWarrantySerializer)
      end.not_to raise_error
    end

    it 'refuses a pre-rename serializer name' do
      expect do
        registry.register(:admin_stock_item_serializer, :bin, serializer: ExtensionFieldsSpecWarrantySerializer)
      end.to raise_error(ArgumentError)
    end

    it 'refuses a dependency that is not a serializer' do
      expect do
        registry.register(:admin_product_presenter, :warranty, serializer: ExtensionFieldsSpecWarrantySerializer)
      end.to raise_error(ArgumentError, /not an API serializer/)
    end
  end
end
