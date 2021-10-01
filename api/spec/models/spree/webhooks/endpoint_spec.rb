require 'spec_helper'

describe Spree::Store do
  describe 'validations' do
    context 'url presence' do
      it 'is valid with url' do
        endpoint = Spree::Webhooks::Endpoint.new(url: 'https://google.com/')
        expect(endpoint.valid?).to be(true)
      end

      it 'is invalid without url' do
        endpoint = Spree::Webhooks::Endpoint.new(url: nil)
        expect(endpoint.valid?).to be(false)
      end
    end
  end
end
