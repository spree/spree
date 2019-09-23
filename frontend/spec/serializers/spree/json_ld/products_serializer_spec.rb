require 'spec_helper'

describe Spree::JsonLd::ProductsSerializer, type: :serializer do
  let :products do
    [
      create(:product, discontinue_on: Date.new(2019, 9, 23)),
      create(:product_in_stock)
    ]
  end
  let(:host) { 'example.com' }
  let(:currency) { 'USD' }

  subject do
    described_class.new(
      products: products,
      host: host,
      currency: currency
    )
  end

  describe '#call' do
    it 'returns JSON-LD representation of products' do
      serialized_products = subject.call

      expect(serialized_products.size).to eq 2
      serialized_products.zip(products).each do |serialized_product, product|
        expect(serialized_product[:@context]).to eq 'https://schema.org/'
        expect(serialized_product[:@type]).to eq 'Product'
        expect(serialized_product[:@id]).to eq "http://example.com/product_#{product.id}"
        expect(serialized_product[:url]).to eq "http://example.com/products/#{product.slug}"
        expect(serialized_product[:image]).to eq ''
        expect(serialized_product[:description]).to eq product.description
        expect(serialized_product[:sku]).to eq product.sku

        offer = serialized_product[:offers]
        expect(offer[:@type]).to eq 'Offer'
        expect(offer[:price]).to eq product.price
        expect(offer[:priceCurrency]).to eq currency
        expect(offer[:url]).to eq "http://example.com/products/#{product.slug}"
      end

      expect(serialized_products[0].dig(:offers, :availabilityEnds)).to eq '2019-09-23'
      expect(serialized_products[1].dig(:offers, :availabilityEnds)).to eq ''

      expect(serialized_products[0].dig(:offers, :availability)).to eq 'OutOfStock'
      expect(serialized_products[1].dig(:offers, :availability)).to eq 'InStock'
    end
  end
end
