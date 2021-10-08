require 'spec_helper'

describe Spree::Webhooks::Endpoints::QueueRequests, :job, :spree_webhooks do
  describe '#call' do
    subject { described_class.call(event: event, body: body) }

    let(:event) { 'order.finalize' }
    let(:body) { {} }
    let(:queue) { 'spree_webhooks' }
    let(:make_request_job) { Spree::Webhooks::Endpoints::MakeRequestJob }

    context 'without subscriptions for the given event' do
      it 'does not queue a job to make a request' do
        expect { subject }.not_to have_enqueued_job(make_request_job).on_queue(queue)
      end
    end

    context 'with subscriptions for the given event' do
      context 'when endpoint subscriptions includes all events (*)' do
        before { stub_request(:post, endpoint.url) }

        let(:endpoint) do
          Spree::Webhooks::Endpoint.create(
            url: 'https://url1.com/',
            subscriptions: ['*'],
            enabled: true
          )
        end

        it 'queues a job to make a request' do
          expect { subject }.to(
            have_enqueued_job(make_request_job).with(body, endpoint.url).on_queue(queue)
          )
        end
      end

      context 'when endpoint subscriptions includes the specific event being used' do
        before { stub_request(:post, endpoint.url) }

        let(:endpoint) do
          Spree::Webhooks::Endpoint.create(
            url: 'https://url2.com/',
            subscriptions: [event],
            enabled: true
          )
        end

        it 'queues a job to make a request' do
          expect { subject }.to(
            have_enqueued_job(make_request_job).with(body, endpoint.url).on_queue(queue)
          )
        end
      end

      context 'when endpoint subscriptions are not enabled' do
        let(:endpoint) do
          Spree::Webhooks::Endpoint.create(
            url: 'https://url3.com/',
            subscriptions: [event],
            enabled: false
          )
        end

        it 'does not queue a job to make a request' do
          expect { subject }.not_to(
            have_enqueued_job(make_request_job).with(body, endpoint.url).on_queue(queue)
          )
        end
      end

      context 'when endpoint subscriptions do not include the event or "*"' do
        let(:endpoint) do
          Spree::Webhooks::Endpoint.create(
            url: 'https://url4.com/',
            subscriptions: ['order.resume'],
            enabled: true
          )
        end

        it 'does not queue a job to make a request' do
          expect { subject }.not_to(
            have_enqueued_job(make_request_job).with(body, endpoint.url).on_queue(queue)
          )
        end
      end
    end
  end
end
