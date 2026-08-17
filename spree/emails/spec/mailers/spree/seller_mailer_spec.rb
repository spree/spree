# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::SellerMailer do
  let(:store) { create(:store, name: 'Sparks Marketplace') }
  let(:seller) { create(:seller, store: store, name: 'Sparks Audio', contact_email: 'seller@example.com') }

  describe '#approved_email' do
    subject(:message) { described_class.approved_email(seller.id) }

    it 'tells the seller they can trade' do
      expect(message.subject).to include('Sparks Marketplace')
      expect(message.to).to eq(['seller@example.com'])
      expect(message.body.encoded).to include('Sparks Audio')
    end

    it 'points them at the dashboard they sign in to' do
      expect(message.body.encoded).to include(Spree::Stores::DashboardUrl.call(store: store))
    end
  end

  describe '#suspended_email' do
    subject(:message) { described_class.suspended_email(seller.id) }

    it 'tells the seller selling has stopped, and how to reach the operator' do
      expect(message.to).to eq(['seller@example.com'])
      expect(message.body.encoded).to include(store.mail_from_address)
    end

    # The operator's note is an internal record — a suspended seller is asked to
    # get in touch rather than handed the verdict verbatim.
    it 'does not leak the operator note' do
      seller.update!(metadata: { 'suspension_reason' => 'Counterfeit goods' })

      expect(message.body.encoded).not_to include('Counterfeit goods')
    end
  end

  describe '#rejected_email' do
    subject(:message) { described_class.rejected_email(seller.id) }

    it 'tells the applicant they were not admitted' do
      expect(message.to).to eq(['seller@example.com'])
      expect(message.body.encoded).to include('Sparks Audio')
    end

    it 'does not leak the operator note' do
      seller.update!(metadata: { 'rejection_reason' => 'Incomplete paperwork' })

      expect(message.body.encoded).not_to include('Incomplete paperwork')
    end
  end

  # The subject is translated inside the store-locale block, not before it.
  # Resolved outside, it would render in whatever locale the delivery job
  # happens to run under — an English subject over a German email.
  describe 'locale' do
    before do
      I18n.backend.store_translations(
        :de,
        spree: { seller_mailer: { approved_email: { subject: 'DE-SUBJECT', heading: 'DE-HEADING' } } }
      )
      store.update!(default_locale: 'de', supported_locales: 'en,de')
    end

    it 'renders the subject in the store locale, not the job locale' do
      message = I18n.with_locale(:en) { described_class.approved_email(seller.id) }

      expect(message.subject).to include('DE-SUBJECT')
    end
  end

  describe 'recipients' do
    it 'reaches the whole team plus the contact address' do
      member = create(:admin_user, email: 'owner@example.com')
      seller.add_user(member)

      expect(described_class.approved_email(seller.id).to).
        to match_array(['owner@example.com', 'seller@example.com'])
    end

    it 'does not send at all when there is nobody to tell' do
      seller.update!(contact_email: nil)

      expect(described_class.approved_email(seller.id).to).to be_blank
    end
  end
end
