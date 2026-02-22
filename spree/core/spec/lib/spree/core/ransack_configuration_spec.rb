require 'spec_helper'

RSpec.describe Spree::RansackConfiguration do
  subject(:config) { described_class.new }

  describe '#add_attribute' do
    it 'adds an attribute to a model' do
      config.add_attribute(Spree::Product, :vendor_id)

      expect(config.custom_attributes_for(Spree::Product)).to contain_exactly('vendor_id')
    end

    it 'adds to existing attributes when called multiple times' do
      config.add_attribute(Spree::Product, :vendor_id)
      config.add_attribute(Spree::Product, :brand_name)

      expect(config.custom_attributes_for(Spree::Product)).to contain_exactly('vendor_id', 'brand_name')
    end

    it 'does not duplicate attributes' do
      config.add_attribute(Spree::Product, :vendor_id)
      config.add_attribute(Spree::Product, :vendor_id)

      expect(config.custom_attributes_for(Spree::Product)).to contain_exactly('vendor_id')
    end

    it 'converts symbol to string' do
      config.add_attribute(Spree::Product, :vendor_id)

      expect(config.custom_attributes_for(Spree::Product)).to eq(['vendor_id'])
    end
  end

  describe '#add_association' do
    it 'adds an association to a model' do
      config.add_association(Spree::Product, :vendor)

      expect(config.custom_associations_for(Spree::Product)).to contain_exactly('vendor')
    end

    it 'adds to existing associations when called multiple times' do
      config.add_association(Spree::Product, :vendor)
      config.add_association(Spree::Product, :brand)

      expect(config.custom_associations_for(Spree::Product)).to contain_exactly('vendor', 'brand')
    end

    it 'does not duplicate associations' do
      config.add_association(Spree::Product, :vendor)
      config.add_association(Spree::Product, :vendor)

      expect(config.custom_associations_for(Spree::Product)).to contain_exactly('vendor')
    end
  end

  describe '#add_scope' do
    it 'adds a scope to a model' do
      config.add_scope(Spree::Product, :by_vendor)

      expect(config.custom_scopes_for(Spree::Product)).to contain_exactly('by_vendor')
    end

    it 'adds to existing scopes when called multiple times' do
      config.add_scope(Spree::Product, :by_vendor)
      config.add_scope(Spree::Product, :featured)

      expect(config.custom_scopes_for(Spree::Product)).to contain_exactly('by_vendor', 'featured')
    end

    it 'does not duplicate scopes' do
      config.add_scope(Spree::Product, :by_vendor)
      config.add_scope(Spree::Product, :by_vendor)

      expect(config.custom_scopes_for(Spree::Product)).to contain_exactly('by_vendor')
    end
  end

  describe '#custom_attributes_for' do
    it 'returns an empty array for models with no custom attributes' do
      expect(config.custom_attributes_for(Spree::Product)).to eq([])
    end
  end

  describe '#custom_associations_for' do
    it 'returns an empty array for models with no custom associations' do
      expect(config.custom_associations_for(Spree::Product)).to eq([])
    end
  end

  describe '#custom_scopes_for' do
    it 'returns an empty array for models with no custom scopes' do
      expect(config.custom_scopes_for(Spree::Product)).to eq([])
    end
  end

  describe '#reset!' do
    it 'clears all custom configurations' do
      config.add_attribute(Spree::Product, :vendor_id)
      config.add_scope(Spree::Order, :by_region)
      config.add_association(Spree::Variant, :vendor)

      config.reset!

      expect(config.custom_attributes_for(Spree::Product)).to eq([])
      expect(config.custom_scopes_for(Spree::Order)).to eq([])
      expect(config.custom_associations_for(Spree::Variant)).to eq([])
    end
  end

  describe 'isolation between models' do
    it 'keeps configurations separate per model' do
      config.add_attribute(Spree::Product, :product_attr)
      config.add_attribute(Spree::Order, :order_attr)

      expect(config.custom_attributes_for(Spree::Product)).to contain_exactly('product_attr')
      expect(config.custom_attributes_for(Spree::Order)).to contain_exactly('order_attr')
    end
  end
end
