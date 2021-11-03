require 'spec_helper'

describe Spree::Product do
  let(:queue_requests) { instance_double(Spree::Webhooks::Subscribers::QueueRequests) }
  let(:product) { create(:product) }
  let(:body) { Spree::Api::V2::Platform::ProductSerializer.new(product).serializable_hash.to_json }

  before do
    ENV['DISABLE_SPREE_WEBHOOKS'] = nil
    allow(Spree::Webhooks::Subscribers::QueueRequests).to receive(:new).and_return(queue_requests)
    allow(queue_requests).to receive(:call).with(any_args)
  end

  after { ENV['DISABLE_SPREE_WEBHOOKS'] = 'true' }

  describe '#discontinue!' do
    it 'executes QueueRequests.call with a product.discontinued event and {} body after invoking cancel' do
      product.discontinue!
      expect(queue_requests).to have_received(:call).with(event: 'product.discontinued', body: body).once
    end
  end
end
