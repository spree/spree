# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::ReimbursementEmailSubscriber do
  let(:reimbursement) { create(:reimbursement) }
  let(:store) { reimbursement.store }
  let(:subscriber) { described_class.new }

  def mock_event(reimbursement_id)
    double('Event', payload: { 'id' => reimbursement_id })
  end

  before do
    store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: true))
  end

  describe 'reimbursement.reimbursed event' do
    it 'sends reimbursement email' do
      expect(Spree::ReimbursementMailer).to receive(:reimbursement_email).with(reimbursement.id).and_return(double(deliver_later: true))

      subscriber.handle(mock_event(reimbursement.id))
    end

    context 'when store does not prefer transactional emails' do
      before do
        store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: false))
      end

      it 'does not send reimbursement email' do
        expect(Spree::ReimbursementMailer).not_to receive(:reimbursement_email)

        subscriber.handle(mock_event(reimbursement.id))
      end
    end

    context 'when reimbursement not found' do
      it 'does not raise an error' do
        expect { subscriber.handle(mock_event(-1)) }.not_to raise_error
      end
    end
  end
end
