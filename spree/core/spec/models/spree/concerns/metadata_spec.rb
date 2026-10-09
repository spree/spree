require 'spec_helper'

RSpec.describe Spree::Metadata do
  let(:product) { build(:product) }

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
end
