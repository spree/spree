require 'spec_helper'

RSpec.describe Spree::Metadata do
  let(:product) { build(:product) }

  describe '#metadata' do
    it 'defaults to an empty hash' do
      expect(product.metadata).to eq({})
    end

    it 'reads back with indifferent access' do
      product.metadata = { 'key' => 'value' }
      expect(product.metadata[:key]).to eq('value')
      expect(product.metadata['key']).to eq('value')
    end
  end

  describe 'merge semantics' do
    it 'supports merging metadata' do
      product.metadata = { 'a' => '1' }
      product.metadata = product.metadata.merge('b' => '2')
      expect(product.metadata).to eq('a' => '1', 'b' => '2')
    end
  end

  describe 'the private_metadata deprecation bridge' do
    it 'reads through to metadata with a warning' do
      product.metadata = { 'key' => 'value' }

      expect(Spree::Deprecation).to receive(:warn).with(/private_metadata is deprecated/)
      expect(product.private_metadata).to eq('key' => 'value')
    end

    it 'writes through to metadata with a warning' do
      expect(Spree::Deprecation).to receive(:warn).with(/private_metadata= is deprecated/)
      product.private_metadata = { 'key' => 'value' }

      expect(product.metadata).to eq('key' => 'value')
    end
  end

  describe 'public_metadata' do
    it 'is gone' do
      expect(product).not_to respond_to(:public_metadata)
    end
  end
end
