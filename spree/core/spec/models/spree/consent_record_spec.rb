require 'spec_helper'

RSpec.describe Spree::ConsentRecord do
  let(:store) { @default_store }
  let(:customer) { create(:customer) }

  describe '.record!' do
    subject(:record) do
      described_class.record!(
        store: store, owner: customer,
        purpose: described_class::TERMS_OF_SERVICE,
        source: 'registration', email: customer.email
      )
    end

    it 'stamps the moment consent was given' do
      expect(record.recorded_at).to be_present
    end

    it 'treats consent as given unless told otherwise' do
      expect(record.accepted).to be(true)
    end
  end

  describe 'the document snapshot' do
    let(:policy) { create(:policy, owner: store, name: 'Terms of Service', body: '<p>Version one</p>') }

    subject(:record) do
      described_class.record!(
        store: store, owner: customer, purpose: described_class::TERMS_OF_SERVICE,
        source: 'registration', policies: [policy]
      )
    end

    it 'names the document that was shown' do
      expect(record.documents_list.first['name']).to eq('Terms of Service')
    end

    it 'fingerprints the text so a later edit is detectable' do
      original_digest = record.documents_list.first['digest']

      policy.update!(body: '<p>Version two</p>')
      later = described_class.record!(
        store: store, owner: customer, purpose: described_class::TERMS_OF_SERVICE,
        source: 'registration', policies: [policy.reload]
      )

      expect(later.documents_list.first['digest']).not_to eq(original_digest)
    end
  end

  it 'records a withdrawal as its own event rather than deleting the acceptance' do
    described_class.record!(store: store, owner: customer, purpose: described_class::EMAIL_MARKETING, source: 'registration')
    described_class.record!(store: store, owner: customer, purpose: described_class::EMAIL_MARKETING, source: 'account', accepted: false)

    history = described_class.where(owner: customer).for_purpose(described_class::EMAIL_MARKETING)

    expect(history.count).to eq(2)
    expect(history.recent_first.first.accepted).to be(false)
  end
end
