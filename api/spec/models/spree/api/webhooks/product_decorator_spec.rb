require 'spec_helper'

describe Spree::Api::Webhooks::ProductDecorator do
  let(:product) { create(:product) }
  let(:body) { Spree::Api::V2::Platform::ProductSerializer.new(product).serializable_hash.to_json }

  describe '#discontinue!' do
    it 'emits the product.discontinued event' do
      expect { product.discontinue! }.to emit_webhook_event('product.discontinued')
    end
  end
end
