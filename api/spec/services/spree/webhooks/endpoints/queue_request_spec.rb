require 'spec_helper'

describe Spree::Webhooks::Endpoints::QueueRequests, :job do
  describe '#call' do
    subject { described_class.call(event: event, payload: payload) }

    let(:event) { 'order.finalize' }
    let(:payload) { {} }

    context 'with DISABLE_SPREE_WEBHOOKS equals "true"' do
      before do
        ENV['DISABLE_SPREE_WEBHOOKS'] = 'true'
        Spree::Webhooks::Endpoint.create(url: url, subscriptions: ['*'], enabled: true)
      end

      after { ENV.delete('DISABLE_SPREE_WEBHOOKS') }

      let(:url) { 'https://url1.com/' }

      it 'returns early without querying for the subscribed events' do
        instance = Spree::Webhooks::Endpoints::QueueRequests.new
        expect(instance).to receive(:call).and_call_original
        expect(instance).not_to receive(:urls_subscribed_to)
        instance.call(event: event, payload: payload)
      end

      it 'does not succeed' do
        expect(subject.success).to eq(false)
      end

      it 'returns a false value' do
        expect(subject.value).to eq(false)
      end
    end

    context 'without DISABLE_SPREE_WEBHOOKS' do
      before { ENV['DISABLE_SPREE_WEBHOOKS'] = nil }

      after { ENV['DISABLE_SPREE_WEBHOOKS'] = 'true' }

      context 'without subscriptions for the given event' do
        it 'does not queue a job to make a request' do
          expect { subject }.not_to(
            have_enqueued_job(Spree::Webhooks::Endpoints::MakeRequest).on_queue('spree_webhooks')
          )
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
              have_enqueued_job(Spree::Webhooks::Endpoints::MakeRequestJob).
                with(payload, endpoint.url).
                on_queue('spree_webhooks')
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
              have_enqueued_job(Spree::Webhooks::Endpoints::MakeRequestJob).
                with(payload, endpoint.url).
                on_queue('spree_webhooks')
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
              have_enqueued_job(Spree::Webhooks::Endpoints::MakeRequestJob).
                with(payload, endpoint.url).
                on_queue('spree_webhooks')
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
              have_enqueued_job(Spree::Webhooks::Endpoints::MakeRequestJob).
                with(endpoint.url).
                on_queue('spree_webhooks')
            )
          end
        end
      end
    end
  end
end
