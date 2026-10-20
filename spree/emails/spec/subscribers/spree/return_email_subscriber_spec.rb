require 'spec_helper'

describe Spree::ReturnEmailSubscriber do
  let(:store) { @default_store }
  let(:return_record) { create(:received_return, store: store) }

  def handle(return_record)
    event = instance_double(Spree::Event, payload: { 'id' => return_record.prefixed_id })
    described_class.new.handle(event)
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
end
