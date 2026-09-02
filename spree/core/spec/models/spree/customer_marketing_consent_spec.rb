require 'spec_helper'

RSpec.describe 'Spree::Customer marketing consent' do
  let(:customer) { create(:customer, accepts_email_marketing: false) }

  it 'records when consent was given' do
    stamped_at = customer.email_marketing_consent_updated_at

    Timecop.travel(1.hour.from_now) do
      customer.update!(accepts_email_marketing: true)
    end

    expect(customer.email_marketing_consent_updated_at).to be > stamped_at
  end

  it 'records when it was withdrawn' do
    customer.update!(accepts_email_marketing: true)
    given_at = customer.email_marketing_consent_updated_at

    Timecop.travel(1.hour.from_now) do
      customer.update!(accepts_email_marketing: false)
    end

    expect(customer.email_marketing_consent_updated_at).to be > given_at
  end

  it 'stamps the decision made at sign-up' do
    expect(customer.email_marketing_consent_updated_at).to be_present
  end

  it 'notes where the person agreed' do
    customer.email_marketing_consent_source_context = 'checkout'
    customer.update!(accepts_email_marketing: true)

    expect(customer.email_marketing_consent_source).to eq('checkout')
  end

  it 'defaults the source to the account page' do
    customer.update!(accepts_email_marketing: true)

    expect(customer.email_marketing_consent_source).to eq('account')
  end

  it 'leaves the timestamp alone when the flag did not move' do
    customer.update!(accepts_email_marketing: true)
    stamped_at = customer.email_marketing_consent_updated_at

    customer.update!(first_name: 'Changed')

    expect(customer.reload.email_marketing_consent_updated_at).to eq(stamped_at)
  end

  describe '#scramble_email_and_names' do
    it 'is deprecated in favour of the anonymizer' do
      expect(Spree::Deprecation).to receive(:warn).at_least(:once)

      customer.scramble_email_and_names
    end

    it 'still erases the customer' do
      allow(Spree::Deprecation).to receive(:warn)

      customer.scramble_email_and_names

      expect(customer.reload.anonymized_at).to be_present
    end
  end
end
