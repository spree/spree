require 'spec_helper'

describe Spree::Webhooks::Subscribers::QueueRequests, :job, :spree_webhooks do
  describe '#call' do
    subject { described_class.call(event_name: event_name, webhook_payload_body: webhook_payload_body) }

    let(:event_name) { 'order.finalize' }
    let(:webhook_payload_body) { {} }
    let(:queue) { 'spree_webhooks' }
    let(:make_request_job) { Spree::Webhooks::Subscribers::MakeRequestJob }

    shared_examples 'queues a job to make a request' do |url|
      before { stub_request(:post, subscriber.url) }

      let(:subscriber) { create(:subscriber, :active, url: url, subscriptions: subscriptions) }

      it do
        expect { subject }.to(
          have_enqueued_job(make_request_job).with(webhook_payload_body, event_name, subscriber).on_queue(queue)
        )
      end
    end

    shared_examples 'does not queue a job to make a request' do
      it { expect { subject }.not_to have_enqueued_job(make_request_job).on_queue(queue) }
    end

    context 'without subscriptions for the given event' do
      before { Spree::Webhooks::Subscriber.delete_all }

      include_examples 'does not queue a job to make a request'
    end

    context 'with subscriptions for the given event' do
      context 'when subscriber subscriptions includes all events (*)' do
        let(:subscriptions) { ['*'] }

        include_examples 'queues a job to make a request', 'https://url1.com/'
      end

      context 'when subscriber subscriptions includes the specific event being used' do
        let(:subscriptions) { [event_name] }

        include_examples 'queues a job to make a request', 'https://url2.com/'
      end

      context 'when subscriber subscriptions are not active' do
        let!(:subscriber) do
          create(:subscriber, url: 'https://url3.com/', subscriptions: [event_name])
        end

        include_examples 'does not queue a job to make a request'
      end

      context 'when subscriber subscriptions do not include the event or "*"' do
        let!(:subscriber) do
          create(:subscriber, :active, url: 'https://url4.com/', subscriptions: ['order.resumed'])
        end

        include_examples 'does not queue a job to make a request'
      end
    end
  end
end
