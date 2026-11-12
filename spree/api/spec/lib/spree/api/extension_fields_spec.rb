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

  describe 'an attribute' do
    before { product.define_singleton_method(:warranty_text) { 'Two years' } }

    it "writes the value of the record's method of that name" do
      registry.attribute(:admin_product_serializer, method: :warranty_text)

      expect(render['warranty_text']).to eq('Two years')
    end

    it 'takes a value supplied for its name' do
      registry.attribute(:admin_product_serializer, :warranty_months, value: ->(record) { record.name.length })

      expect(render['warranty_months']).to eq(6)
    end

    it 'is left out unless expanded, when it waits for an expand' do
      registry.attribute(:admin_product_serializer, method: :warranty_text, expand: true)

      expect(render).not_to have_key('warranty_text')
      expect(render(expand: ['warranty_text'])['warranty_text']).to eq('Two years')
    end
  end

  describe 'an association' do
    context 'with one related record, shown always' do
      before do
        product.define_singleton_method(:warranty) { self }
        registry.association(:admin_product_serializer, one: :warranty, serializer: ExtensionFieldsSpecWarrantySerializer)
      end

      it 'writes the related record with its own serializer' do
        expect(render['warranty']).to include('months' => 6)
      end

      it 'drops the field once it is unregistered' do
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
    end

    it 'writes a list of related records' do
      product.define_singleton_method(:warranty_claims) { [self, self] }
      registry.association(:admin_product_serializer, many: :warranty_claims, serializer: ExtensionFieldsSpecWarrantySerializer)

      expect(render['warranty_claims'].map { |claim| claim['months'] }).to eq([6, 6])
    end

    it 'writes null when there is no related record' do
      registry.association(:admin_product_serializer, one: :warranty, serializer: ExtensionFieldsSpecWarrantySerializer, value: ->(_record) {})

      expect(render).to include('warranty' => nil)
    end

    context 'when it waits for an expand' do
      before do
        registry.association(:admin_product_serializer, one: :warranty, serializer: 'ExtensionFieldsSpecWarrantySerializer',
                                                        expand: true, value: ->(record) { record })
      end

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
  end

  it "never leaks a parent serializer's field into a subclass" do
    registry.attribute(:product_serializer, :warranty_text, value: ->(_record) { 'Two years' })
    render(Spree.api.product_serializer)
    subclass = Class.new(Spree::Api::V3::ProductSerializer)

    expect(render(subclass)).not_to have_key('warranty_text')
  end

  describe 'registering' do
    it 'refuses a name another extension took on that serializer, whichever kind of field' do
      registry.attribute(:admin_product_serializer, method: :warranty)

      expect do
        registry.association(:admin_product_serializer, one: 'warranty', serializer: ExtensionFieldsSpecWarrantySerializer)
      end.to raise_error(described_class::DuplicateField, /warranty/)
    end

    it 'refuses a name the serializer already writes' do
      expect { registry.attribute(:admin_product_serializer, method: :name) }.to raise_error(described_class::DuplicateField)
    end

    it 'allows the same name on another serializer' do
      registry.attribute(:admin_product_serializer, method: :warranty)

      expect { registry.attribute(:seller_product_serializer, method: :warranty) }.not_to raise_error
    end

    it 'needs either a name with a value or method: for an attribute' do
      expect { registry.attribute(:admin_product_serializer) }.to raise_error(ArgumentError, /name or method:/)
      expect { registry.attribute(:admin_product_serializer, :warranty_text) }.to raise_error(ArgumentError, /needs value:/)
      expect do
        registry.attribute(:admin_product_serializer, method: :warranty_text, value: ->(_record) {})
      end.to raise_error(ArgumentError, /takes no value:/)
    end

    it 'needs exactly one of one: and many: for an association' do
      expect do
        registry.association(:admin_product_serializer, serializer: ExtensionFieldsSpecWarrantySerializer)
      end.to raise_error(ArgumentError, /one: or many:/)
      expect do
        registry.association(:admin_product_serializer, one: :warranty, many: :warranties, serializer: ExtensionFieldsSpecWarrantySerializer)
      end.to raise_error(ArgumentError, /one: or many:/)
    end

    it 'refuses a pre-rename serializer name' do
      expect { registry.attribute(:admin_stock_item_serializer, method: :bin) }.to raise_error(ArgumentError)
    end

    it 'refuses a dependency that is not a serializer' do
      expect do
        registry.attribute(:admin_product_presenter, method: :warranty)
      end.to raise_error(ArgumentError, /not an API serializer/)
    end
  end
end
