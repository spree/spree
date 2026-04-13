require 'spec_helper'

RSpec.describe Spree::Metadata do
  let(:product) { build(:product) }

  describe '#metadata' do
    it 'reads from metadata' do
      product.metadata = { 'key' => 'value' }
      expect(product.metadata).to eq('key' => 'value')
    end
  end

  describe '#metadata=' do
    it 'writes to metadata' do
      product.metadata = { 'key' => 'value' }
      expect(product.metadata).to eq('key' => 'value')
    end
  end

  describe 'merge semantics' do
    it 'supports merging metadata' do
      product.metadata = { 'a' => '1' }
      product.metadata = product.metadata.merge('b' => '2')
      expect(product.metadata).to eq('a' => '1', 'b' => '2')
    end
  end
end
