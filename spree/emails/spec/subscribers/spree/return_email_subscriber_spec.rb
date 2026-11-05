require 'spec_helper'

describe Spree::ReturnEmailSubscriber do
  let(:store) { @default_store }
  let(:return_record) { create(:received_return, store: store) }

  def handle(return_record, name: 'return.refunded')
    event = instance_double(Spree::Event, name: name, payload: { 'id' => return_record.prefixed_id })
    described_class.new.call(event)
  end

  it 'mails the customer when money went back' do
    create(:store_credit, originator: return_record, amount: 10)

    expect {
      handle(return_record)
    }.to have_enqueued_job(ActionMailer::MailDeliveryJob).with(
      'Spree::ReturnMailer', 'refunded_email', 'deliver_now', args: [return_record.id]
    )
  end

  it 'stays silent when the return closed with nothing refunded' do
    expect { handle(return_record) }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
  end

  # The EU Consumer Rights Directive asks for a durable acknowledgement of a
  # withdrawal sent through the website.
  it 'acknowledges a request the moment it is opened' do
    expect {
      handle(return_record, name: 'return.requested')
    }.to have_enqueued_job(ActionMailer::MailDeliveryJob).with(
      'Spree::ReturnMailer', 'requested_email', 'deliver_now', args: [return_record.id]
    )
  end

  it 'tells the customer where to send the goods once approved' do
    expect {
      handle(return_record, name: 'return.approved')
    }.to have_enqueued_job(ActionMailer::MailDeliveryJob).with(
      'Spree::ReturnMailer', 'approved_email', 'deliver_now', args: [return_record.id]
    )
  end

  it 'sends nothing when the store sends its own emails' do
    store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: false))

    expect { handle(return_record, name: 'return.requested') }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
  end
end
