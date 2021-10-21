require 'spec_helper'

describe Spree::Webhooks::Subscriber do
  describe 'validations' do
    context 'url format (UrlValidator)' do
      it 'is invalid with an invalid url' do
        endpoint = described_class.new(url: 'google.com')
        expect(endpoint.valid?).to be(false)
      end

      it 'is valid with a valid url' do
        endpoint = described_class.new(url: 'http://google.com/')
        expect(endpoint.valid?).to be(true)
      end
    end

    context 'url path' do
      it 'is invalid a url without path' do
        endpoint = described_class.new(url: 'http://google.com')
        expect(endpoint.valid?).to be(false)
        expect(endpoint.errors.messages).to eq(url: ['the URL must have a path'])
      end
    end
  end
end
