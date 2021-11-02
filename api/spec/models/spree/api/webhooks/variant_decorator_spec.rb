require 'spec_helper'

describe Spree::Variant do
  let(:variant) { create(:variant) }

  describe '#discontinue!' do
    extend RSpec::Matchers::DSL

    matcher :emit_webhook_event do |event_to_emit|
      match do |obj_method|
        ENV['DISABLE_SPREE_WEBHOOKS'] = nil

        queue_requests = instance_double(Spree::Webhooks::Subscribers::QueueRequests)

        allow(Spree::Webhooks::Subscribers::QueueRequests).to receive(:new).and_return(queue_requests)
        allow(queue_requests).to receive(:call).with(any_args)

        obj_method.call
        expect(queue_requests).to have_received(:call).with(event: event_to_emit, body: body).once

        ENV['DISABLE_SPREE_WEBHOOKS'] = 'true'
      end

      failure_message do |obj_method|
        # positive look-behinds must have a fixed length, using straighforward match instead
        proc_body = obj_method.source.squish[/(expect *({|do) *)(.*?)( *(}|end).to)/, 3]
        "Expected that executing `#{proc_body}` emits the `#{expected}` Webhook event.\n" \
          "Check that `#{proc_body}` does implement `queue_webhooks_requests!` passing `#{expected}` as argument."
      end
      
      supports_block_expectations
    end

    context 'emitting variant.discontinued' do
      let(:body) { Spree::Api::V2::Platform::VariantSerializer.new(variant).serializable_hash.to_json }

      it { expect { variant.discontinue! }.to emit_webhook_event('variant.discontinued') }
    end
  end
end
