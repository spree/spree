require 'spec_helper'

describe Spree::Webhooks::Subscribers::MakeRequestJob do
  let(:event) { 'order.cancel' }
  let(:queue) { 'spree_webhooks' }
  let(:subscriber) { create(:subscriber, :active) }
  let(:webhook_payload_body) { {} }

  it 'enqueues a HTTP request using Spree::Webhooks::Subscribers::HandleRequest', :job do
    expect { described_class.perform_later(webhook_payload_body, event, subscriber, 1) }.to have_enqueued_job.on_queue(queue)
  end

  it 'does not raise if used with the expected arguments', :job do
    allow(Spree::Webhooks::Subscribers::HandleRequest).to receive_message_chain(:new, :call)
    expect { described_class.perform_now(webhook_payload_body, event, subscriber) }.not_to raise_error
  end
end
