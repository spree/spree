require 'spec_helper'

describe Spree::V2::Storefront::ProductSerializer do
  subject { described_class.new(product, params: serializer_params).serializable_hash }

  include_context 'API v2 serializers params'

  let(:product) { create(:product) }

  context 'with tags' do
    before { product.update(tag_list: ['tag1', 'tag2']) }

    it 'returns tags' do
      expect(subject[:data][:attributes][:tags]).to eq ['tag1', 'tag2']
    end
  end

  context 'with labels' do
    before { product.update(label_list: ['label1', 'label2']) }

    it 'returns labels' do
      expect(subject[:data][:attributes][:labels]).to eq ['label1', 'label2']
    end
  end
end
