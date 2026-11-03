require 'spec_helper'

describe Spree::ExchangeEmailSubscriber do
  let(:store) { @default_store }
  let(:exchange) { create(:exchange, store: store) }

  def handle(name)
    event = instance_double(Spree::Event, name: name, payload: { 'id' => exchange.prefixed_id })
    described_class.new.call(event)
  end

  it 'acknowledges a request the moment it is opened' do
    expect { handle('exchange.requested') }.to have_enqueued_job(ActionMailer::MailDeliveryJob).with(
      'Spree::ExchangeMailer', 'requested_email', 'deliver_now', args: [exchange.id]
    )
  end

  it 'tells the customer where to send the goods once approved' do
    expect { handle('exchange.approved') }.to have_enqueued_job(ActionMailer::MailDeliveryJob).with(
      'Spree::ExchangeMailer', 'approved_email', 'deliver_now', args: [exchange.id]
    )
  end
end
