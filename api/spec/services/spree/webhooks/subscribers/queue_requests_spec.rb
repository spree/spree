require 'spec_helper'

describe Spree::Webhooks::Subscribers::QueueRequests, :job, :spree_webhooks do
  describe '#call' do
    subject { described_class.call(event: event, body: body) }

    let(:event) { 'order.finalize' }
    let(:body) { {} }
    let(:queue) { 'spree_webhooks' }
    let(:make_request_job) { Spree::Webhooks::Subscribers::MakeRequestJob }

    context 'without subscriptions for the given event' do
      it 'does not queue a job to make a request' do
        expect { subject }.not_to have_enqueued_job(make_request_job).on_queue(queue)
      end
    end

    context 'with subscriptions for the given event' do
      context 'when subscriber subscriptions includes all events (*)' do
        before { stub_request(:post, subscriber.url) }

        let(:subscriber) do
          Spree::Webhooks::Subscriber.create(
            url: 'https://url1.com/',
            subscriptions: ['*'],
            active: true
          )
        end

        it 'queues a job to make a request' do
          expect { subject }.to(
            have_enqueued_job(make_request_job).with(body, event, subscriber.url).on_queue(queue)
          )
        end
      end

      context 'when subscriber subscriptions includes the specific event being used' do
        before { stub_request(:post, subscriber.url) }

        let(:subscriber) do
          Spree::Webhooks::Subscriber.create(
            url: 'https://url2.com/',
            subscriptions: [event],
            active: true
          )
        end

        it 'queues a job to make a request' do
          expect { subject }.to(
            have_enqueued_job(make_request_job).with(body, event, subscriber.url).on_queue(queue)
          )
        end
      end

      context 'when subscriber subscriptions are not active' do
        let!(:subscriber) do
          Spree::Webhooks::Subscriber.create(
            url: 'https://url3.com/',
            subscriptions: [event],
            active: false
          )
        end

        it 'does not queue a job to make a request' do
          expect { subject }.not_to have_enqueued_job(make_request_job).on_queue(queue)
        end
      end

      context 'when subscriber subscriptions do not include the event or "*"' do
        let!(:subscriber) do
          Spree::Webhooks::Subscriber.create(
            url: 'https://url4.com/',
            subscriptions: ['order.resume'],
            active: true
          )
        end

        it 'does not queue a job to make a request' do
          expect { subject }.not_to have_enqueued_job(make_request_job).on_queue(queue)
        end
      end
    end
  end
end
