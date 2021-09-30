require 'spec_helper'

describe Spree::Webhooks::Endpoints::QueueRequests, :job do
  describe '#call' do
    let(:event) { 'order.finalize' }
    let(:payload) { {} }

    context 'without subscriptions for the given event' do
      it 'does not make any HTTP request' do
        expect { subject.call(event: event, payload: payload) }.not_to(
          have_enqueued_job(Spree::Webhooks::Endpoints::MakeRequest).on_queue('spree_webhooks')
        )
      end
    end

    context 'with subscriptions for the given event' do
      context 'when endpoint subscriptions includes all events (*)' do
        before { stub_request(:post, endpoint.url) }

        let(:endpoint) do
          Spree::Webhooks::Endpoint.create(url: 'https://url1.com/', subscriptions: ['*'], enabled: true)
        end

        it 'makes a HTTP request to its URL' do
          expect { subject.call(event: event, payload: payload) }.to(
            have_enqueued_job(Spree::Webhooks::Endpoints::MakeRequestJob)
              .with(endpoint.url)
              .on_queue('spree_webhooks')
          )
        end
      end

      context 'when endpoint subscriptions includes the specific event being used' do
        before { stub_request(:post, endpoint.url) }

        let(:endpoint) do
          Spree::Webhooks::Endpoint.create(url: 'https://url2.com/', subscriptions: [event], enabled: true)
        end

        it 'makes a HTTP request to its URL' do
          expect { subject.call(event: event, payload: payload) }.to(
            have_enqueued_job(Spree::Webhooks::Endpoints::MakeRequestJob)
              .with(endpoint.url)
              .on_queue('spree_webhooks')
          )
        end
      end

      context 'when endpoint subscriptions are not enabled' do
        let(:endpoint) do
          Spree::Webhooks::Endpoint.create(url: 'https://url3.com/', subscriptions: [event], enabled: false)
        end

        it 'does not make a HTTP request' do
          expect { subject.call(event: event, payload: payload) }.not_to(
            have_enqueued_job(Spree::Webhooks::Endpoints::MakeRequestJob)
              .with(endpoint.url)
              .on_queue('spree_webhooks')
          )
        end
      end

      context 'when endpoint subscriptions do not include the event or "*"' do
        let(:endpoint) do
          Spree::Webhooks::Endpoint.create(url: 'https://url4.com/', subscriptions: ['order.resume'], enabled: true)
        end

        it 'does not make a HTTP request' do
          expect { subject.call(event: event, payload: payload) }.not_to(
            have_enqueued_job(Spree::Webhooks::Endpoints::MakeRequestJob)
              .with(endpoint.url)
              .on_queue('spree_webhooks')
          )
        end
      end
    end
  end
end
