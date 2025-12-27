require 'spec_helper'

RSpec.describe Spree::Products::QueueStatusChangedWebhook, :job do
  subject { described_class.call(ids: products.map(&:id), event: event) }
  let!(:product) { create(:product) }
  let!(:products) { [product] }
  let!(:webhook_subscriber) { create(:webhook_subscriber, :active, subscriptions: ['*']) }

  shared_examples 'triggers change status webhooks' do |event|
    it 'triggers product activated webhooks' do
      queue_requests = instance_double(Spree::Webhooks::Subscribers::QueueRequests)

      allow(Spree::Webhooks::Subscribers::QueueRequests).to receive(:new).and_return(queue_requests)
      allow(queue_requests).to receive(:call)
      expect(queue_requests).to receive(:call).with(event_name: "product.#{event}", webhook_payload_body: anything, record: product)

      perform_enqueued_jobs do
        with_webhooks_enabled { Timecop.freeze { subject } }
      end
    end
  end

  context 'on activate' do
    let(:event) { 'activated' }

    it_behaves_like 'triggers change status webhooks', 'activated'
  end

  context 'on draft' do
    let(:event) { 'drafted' }

    it_behaves_like 'triggers change status webhooks', 'drafted'
  end

  context 'on archive' do
    let(:event) { 'archived' }

    it_behaves_like 'triggers change status webhooks', 'archived'
  end
end
