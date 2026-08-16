# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::VendorMailer do
  let(:store) { create(:store, name: 'Sparks Marketplace') }
  let(:vendor) { create(:vendor, store: store, name: 'Sparks Audio', contact_email: 'seller@example.com') }

  describe '#approved_email' do
    subject(:message) { described_class.approved_email(vendor.id) }

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
    subject(:message) { described_class.suspended_email(vendor.id) }

    it 'tells the seller selling has stopped, and how to reach the operator' do
      expect(message.to).to eq(['seller@example.com'])
      expect(message.body.encoded).to include(store.mail_from_address)
    end

    # The operator's note is an internal record — a suspended seller is asked to
    # get in touch rather than handed the verdict verbatim.
    it 'does not leak the operator note' do
      vendor.update!(metadata: { 'suspension_reason' => 'Counterfeit goods' })

      expect(message.body.encoded).not_to include('Counterfeit goods')
    end
  end

  describe '#rejected_email' do
    subject(:message) { described_class.rejected_email(vendor.id) }

    it 'tells the applicant they were not admitted' do
      expect(message.to).to eq(['seller@example.com'])
      expect(message.body.encoded).to include('Sparks Audio')
    end

    it 'does not leak the operator note' do
      vendor.update!(metadata: { 'rejection_reason' => 'Incomplete paperwork' })

      expect(message.body.encoded).not_to include('Incomplete paperwork')
    end
  end

  describe 'recipients' do
    it 'reaches the whole team plus the contact address' do
      member = create(:admin_user, email: 'owner@example.com')
      vendor.add_user(member)

      expect(described_class.approved_email(vendor.id).to).
        to match_array(['owner@example.com', 'seller@example.com'])
    end

    it 'does not send at all when there is nobody to tell' do
      vendor.update!(contact_email: nil)

      expect(described_class.approved_email(vendor.id).to).to be_blank
    end
  end
end
