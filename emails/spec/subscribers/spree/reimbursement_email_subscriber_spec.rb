# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::ReimbursementEmailSubscriber do
  include ActiveJob::TestHelper

  let(:reimbursement) { create(:reimbursement) }
  let(:store) { reimbursement.store }

  def publish_event(event_name, reimbursement_id = reimbursement.id)
    perform_enqueued_jobs(only: Spree::Events::SubscriberJob) do
      Spree::Events.publish(
        event_name,
        { 'id' => reimbursement_id }
      )
    end
  end

  before do
    store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: true))
    # Unregister first to avoid duplicate subscriptions from engine initialization
    described_class.unregister!
    described_class.register!
  end

  after do
    described_class.unregister!
  end

  describe 'reimbursement.reimbursed event' do
    it 'sends reimbursement email' do
      expect(Spree::ReimbursementMailer).to receive(:reimbursement_email).with(reimbursement.id).and_return(double(deliver_later: true))

      publish_event('reimbursement.reimbursed')
    end

    context 'when store does not prefer transactional emails' do
      before do
        store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: false))
      end

      it 'does not send reimbursement email' do
        expect(Spree::ReimbursementMailer).not_to receive(:reimbursement_email)

        publish_event('reimbursement.reimbursed')
      end
    end

    context 'when reimbursement not found' do
      it 'does not raise an error' do
        expect { publish_event('reimbursement.reimbursed', -1) }.not_to raise_error
      end
    end
  end
end
