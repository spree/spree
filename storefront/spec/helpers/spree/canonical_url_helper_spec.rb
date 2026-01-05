require 'spec_helper'

RSpec.describe Spree::CanonicalUrlHelper, type: :helper do
  let(:request_double) do
    double('request',
      host: 'example.com',
      protocol: 'https://',
      path: '/products/test-product'
    )
  end

  before do
    allow(helper).to receive(:request).and_return(request_double)
  end

  describe '#canonical_path' do
    it 'returns the request path' do
      expect(helper.canonical_path).to eq('/products/test-product')
    end

    context 'with blank path' do
      before do
        allow(request_double).to receive(:path).and_return('')
      end

      it 'returns root path' do
        expect(helper.canonical_path).to eq('/')
      end
    end
  end

  describe '#canonical_href' do
    it 'returns full URL with protocol, host, and path' do
      expect(helper.canonical_href).to eq('https://example.com/products/test-product')
    end

    context 'with custom host' do
      it 'uses the provided host' do
        expect(helper.canonical_href('store.example.com')).to eq('https://store.example.com/products/test-product')
      end
    end
  end

  describe '#canonical_tag' do
    it 'returns a link tag with canonical rel' do
      result = helper.canonical_tag
      expect(result).to include('rel="canonical"')
      expect(result).to include('href="https://example.com/products/test-product"')
    end

    context 'with custom host' do
      it 'uses the provided host in the href' do
        result = helper.canonical_tag('store.example.com')
        expect(result).to include('href="https://store.example.com/products/test-product"')
      end
    end
  end
end
