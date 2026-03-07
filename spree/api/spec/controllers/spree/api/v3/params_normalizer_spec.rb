require 'spec_helper'

RSpec.describe Spree::Api::V3::ParamsNormalizer do
  let(:test_controller_class) do
    Class.new(ActionController::API) do
      include Spree::Api::V3::ParamsNormalizer

      # Expose private methods for testing
      public :resolve_prefixed_ids, :normalize_nested_attributes, :prefixed_id?, :decode_prefixed_id

      def model_class
        Spree::Taxon
      end
    end
  end

  let(:controller) { test_controller_class.new }

  describe '#prefixed_id?' do
    it 'returns true for prefixed IDs' do
      expect(controller.prefixed_id?('prod_86Rf07xd4z')).to be true
      expect(controller.prefixed_id?('variant_k5nR8xLq')).to be true
      expect(controller.prefixed_id?('txn_abc123XYZ')).to be true
    end

    it 'returns false for non-prefixed values' do
      expect(controller.prefixed_id?('12345')).to be false
      expect(controller.prefixed_id?(123)).to be false
      expect(controller.prefixed_id?(nil)).to be false
      expect(controller.prefixed_id?('')).to be false
    end
  end

  describe '#decode_prefixed_id' do
    it 'decodes a prefixed ID to an integer' do
      product = create(:product)
      decoded = controller.decode_prefixed_id(product.prefixed_id)
      expect(decoded).to eq(product.id)
    end
  end

  describe '#resolve_prefixed_ids' do
    it 'decodes _id params' do
      product = create(:product)
      hash = { 'product_id' => product.prefixed_id, 'name' => 'Test' }.with_indifferent_access
      result = controller.resolve_prefixed_ids(hash)

      expect(result['product_id']).to eq(product.id)
      expect(result['name']).to eq('Test')
    end

    it 'decodes _ids array params' do
      taxon1 = create(:taxon)
      taxon2 = create(:taxon)
      hash = { 'taxon_ids' => [taxon1.prefixed_id, taxon2.prefixed_id] }.with_indifferent_access
      result = controller.resolve_prefixed_ids(hash)

      expect(result['taxon_ids']).to eq([taxon1.id, taxon2.id])
    end

    it 'recurses into nested hashes' do
      variant = create(:variant)
      hash = { 'line_items' => [{ 'variant_id' => variant.prefixed_id, 'quantity' => 2 }] }.with_indifferent_access
      result = controller.resolve_prefixed_ids(hash)

      expect(result['line_items'][0]['variant_id']).to eq(variant.id)
      expect(result['line_items'][0]['quantity']).to eq(2)
    end

    it 'leaves non-prefixed IDs unchanged' do
      hash = { 'product_id' => 42, 'name' => 'Test' }.with_indifferent_access
      result = controller.resolve_prefixed_ids(hash)

      expect(result['product_id']).to eq(42)
    end

    it 'handles nested hash params' do
      address = create(:address)
      hash = { 'ship_address' => { 'id' => address.prefixed_id } }.with_indifferent_access
      # 'id' doesn't end in '_id' so it stays unchanged
      result = controller.resolve_prefixed_ids(hash)
      expect(result['ship_address']['id']).to eq(address.prefixed_id)
    end
  end

  describe '#normalize_nested_attributes' do
    it 'converts flat nested keys to _attributes format' do
      hash = {
        'name' => 'Categories',
        'taxon_rules' => [{ 'type' => 'Spree::TaxonRule::IncludeTag', 'value' => 'sale' }]
      }.with_indifferent_access

      result = controller.normalize_nested_attributes(hash)

      expect(result).not_to have_key('taxon_rules')
      expect(result['taxon_rules_attributes']).to eq([{ 'type' => 'Spree::TaxonRule::IncludeTag', 'value' => 'sale' }])
      expect(result['name']).to eq('Categories')
    end

    it 'does not rename keys that already have _attributes suffix' do
      hash = {
        'taxon_rules_attributes' => [{ 'type' => 'Spree::TaxonRule::IncludeTag' }]
      }.with_indifferent_access

      result = controller.normalize_nested_attributes(hash)

      expect(result['taxon_rules_attributes']).to eq([{ 'type' => 'Spree::TaxonRule::IncludeTag' }])
    end

    it 'does not rename keys that are not nested attributes' do
      hash = { 'name' => 'Test', 'position' => 1 }.with_indifferent_access
      result = controller.normalize_nested_attributes(hash)

      expect(result).to eq(hash)
    end
  end
end
