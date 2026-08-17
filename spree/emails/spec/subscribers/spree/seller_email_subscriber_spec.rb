# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::SellerEmailSubscriber do
  let(:store) { create(:store) }
  let(:seller) { create(:seller, store: store, contact_email: 'seller@example.com') }
  let(:subscriber) { described_class.new }

  # The `on` DSL routes through `call` by event name.
  def mock_event(record, name)
    double('Event', name: name, payload: { 'id' => record.prefixed_id },
                    matches?: false)
  end

  before do
    store.update!(preferences: store.preferences.merge(send_seller_transactional_emails: true))
  end

  describe 'seller.approved event' do
    it 'sends the approved email' do
      expect(Spree::SellerMailer).to receive(:approved_email).with(seller.id).
        and_return(double(deliver_later: true))

      subscriber.call(mock_event(seller, 'seller.approved'))
    end

    # Sellers are a different audience from shoppers, so silencing customer
    # receipts must not silence seller mail, and vice versa.
    context 'when the store does not prefer seller transactional emails' do
      before do
        store.update!(preferences: store.preferences.merge(send_seller_transactional_emails: false))
      end

      it 'sends nothing' do
        expect(Spree::SellerMailer).not_to receive(:approved_email)

        subscriber.call(mock_event(seller, 'seller.approved'))
      end
    end

    context 'when the consumer preference alone is off' do
      before do
        store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: false))
      end

      it 'still tells the seller' do
        expect(Spree::SellerMailer).to receive(:approved_email).and_return(double(deliver_later: true))

        subscriber.call(mock_event(seller, 'seller.approved'))
      end
    end

    context 'when the seller is gone' do
      it 'does not raise' do
        event = mock_event(seller, 'seller.approved')
        seller.destroy

        expect { subscriber.call(event) }.not_to raise_error
      end
    end
  end

  describe 'seller.suspended event' do
    it 'sends the suspended email' do
      expect(Spree::SellerMailer).to receive(:suspended_email).with(seller.id).
        and_return(double(deliver_later: true))

      subscriber.call(mock_event(seller, 'seller.suspended'))
    end
  end

  describe 'seller.rejected event' do
    it 'sends the rejected email' do
      expect(Spree::SellerMailer).to receive(:rejected_email).with(seller.id).
        and_return(double(deliver_later: true))

      subscriber.call(mock_event(seller, 'seller.rejected'))
    end
  end

  # Inviting a seller creates an Invitation, which mails the invitee through
  # InvitationEmailSubscriber. A seller.invited email would be a second message
  # to the same address about the same thing.
  describe 'seller.invited event' do
    it 'is not subscribed to' do
      expect(described_class.subscription_patterns).not_to include('seller.invited')
    end
  end
end
