require 'spec_helper'

RSpec.describe Spree::Metadata, type: :model do
  let(:product) { create(:product) }

  describe 'associations' do
    it 'has many metafields' do
      expect(product).to respond_to(:metafields)
    end

    it 'has many public_metafields' do
      expect(product).to respond_to(:public_metafields)
    end

    it 'has many private_metafields' do
      expect(product).to respond_to(:private_metafields)
    end
  end

  describe '#metafield' do
    let!(:metafield) { create(:metafield, resource: product, key: 'color', value: 'red') }

    it 'finds metafield by key' do
      result = product.metafield('color')
      expect(result).to eq(metafield)
    end

    it 'returns nil when metafield not found' do
      result = product.metafield('nonexistent')
      expect(result).to be_nil
    end

    it 'respects visibility parameter' do
      private_metafield = create(:metafield, resource: product, key: 'secret', visibility: 'private')

      result = product.metafield('secret', visibility: 'private')
      expect(result).to eq(private_metafield)

      result = product.metafield('secret', visibility: 'public')
      expect(result).to be_nil
    end
  end

  describe '#set_metafield' do
    it 'creates new metafield' do
      expect {
        product.set_metafield('color', 'blue')
      }.to change(product.metafields, :count).by(1)

      metafield = product.metafield('color')
      expect(metafield.value).to eq('blue')
      expect(metafield.kind).to eq('string')
    end

    it 'updates existing metafield' do
      create(:metafield, resource: product, key: 'color', value: 'red')

      expect {
        product.set_metafield('color', 'blue')
      }.not_to change(product.metafields, :count)

      metafield = product.metafield('color')
      expect(metafield.value).to eq('blue')
    end

    it 'accepts kind parameter' do
      product.set_metafield('count', 42, kind: 'integer')

      metafield = product.metafield('count')
      expect(metafield.kind).to eq('integer')
      expect(metafield.typed_value).to eq(42)
    end
  end

  describe '#remove_metafield' do
    let!(:metafield) { create(:metafield, resource: product, key: 'color') }

    it 'removes metafield' do
      expect {
        product.remove_metafield('color')
      }.to change(product.metafields, :count).by(-1)
    end

    it 'does not remove non-matching metafields' do
      expect {
        product.remove_metafield('nonexistent')
      }.not_to change(product.metafields, :count)
    end
  end

  describe 'legacy metadata compatibility' do
    before do
      product.update!(
        public_metadata: { 'legacy' => { 'key1' => 'value1' } },
        private_metadata: { 'legacy' => { 'key2' => 'value2' } }
      )
    end

    context 'when no metafields exist' do
      it 'returns legacy public_metadata' do
        expect(product.public_metadata).to eq('legacy' => { 'key1' => 'value1' })
      end

      it 'returns legacy private_metadata' do
        expect(product.private_metadata).to eq('legacy' => { 'key2' => 'value2' })
      end
    end

    context 'when metafields exist' do
      let!(:public_metafield) { create(:metafield, resource: product, key: 'key3', value: 'value3', visibility: 'public') }
      let!(:private_metafield) { create(:metafield, resource: product, key: 'key4', value: 'value4', visibility: 'private') }

      it 'merges legacy and new data for public metadata' do
        product.public_metafields.reload
        result = product.public_metadata_hash

        expect(result).to include('legacy' => { 'key1' => 'value1' })
        expect(result).to include('key3' => 'value3')
      end

      it 'merges legacy and new data for private metadata' do
        product.private_metafields.reload
        result = product.private_metadata_hash

        expect(result).to include('legacy' => { 'key2' => 'value2' })
        expect(result).to include('key4' => 'value4')
      end
    end
  end
end
