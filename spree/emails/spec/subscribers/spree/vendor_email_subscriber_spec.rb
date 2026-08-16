# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::VendorEmailSubscriber do
  let(:store) { create(:store) }
  let(:vendor) { create(:vendor, store: store, contact_email: 'seller@example.com') }
  let(:subscriber) { described_class.new }

  # The `on` DSL routes through `call` by event name.
  def mock_event(record, name)
    double('Event', name: name, payload: { 'id' => record.prefixed_id },
                    matches?: false)
  end

  before do
    store.update!(preferences: store.preferences.merge(send_vendor_transactional_emails: true))
  end

  describe 'vendor.approved event' do
    it 'sends the approved email' do
      expect(Spree::VendorMailer).to receive(:approved_email).with(vendor.id).
        and_return(double(deliver_later: true))

      subscriber.call(mock_event(vendor, 'vendor.approved'))
    end

    # Sellers are a different audience from shoppers, so silencing customer
    # receipts must not silence seller mail, and vice versa.
    context 'when the store does not prefer vendor transactional emails' do
      before do
        store.update!(preferences: store.preferences.merge(send_vendor_transactional_emails: false))
      end

      it 'sends nothing' do
        expect(Spree::VendorMailer).not_to receive(:approved_email)

        subscriber.call(mock_event(vendor, 'vendor.approved'))
      end
    end

    context 'when the consumer preference alone is off' do
      before do
        store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: false))
      end

      it 'still tells the vendor' do
        expect(Spree::VendorMailer).to receive(:approved_email).and_return(double(deliver_later: true))

        subscriber.call(mock_event(vendor, 'vendor.approved'))
      end
    end

    context 'when the vendor is gone' do
      it 'does not raise' do
        event = mock_event(vendor, 'vendor.approved')
        vendor.destroy

        expect { subscriber.call(event) }.not_to raise_error
      end
    end
  end

  describe 'vendor.suspended event' do
    it 'sends the suspended email' do
      expect(Spree::VendorMailer).to receive(:suspended_email).with(vendor.id).
        and_return(double(deliver_later: true))

      subscriber.call(mock_event(vendor, 'vendor.suspended'))
    end
  end

  describe 'vendor.rejected event' do
    it 'sends the rejected email' do
      expect(Spree::VendorMailer).to receive(:rejected_email).with(vendor.id).
        and_return(double(deliver_later: true))

      subscriber.call(mock_event(vendor, 'vendor.rejected'))
    end
  end

  # Inviting a vendor creates an Invitation, which mails the invitee through
  # InvitationEmailSubscriber. A vendor.invited email would be a second message
  # to the same address about the same thing.
  describe 'vendor.invited event' do
    it 'is not subscribed to' do
      expect(described_class.subscription_patterns).not_to include('vendor.invited')
    end
  end
end
