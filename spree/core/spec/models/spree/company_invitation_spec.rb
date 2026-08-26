require 'spec_helper'

describe Spree::CompanyInvitation, type: :model do
  let(:store) { @default_store }
  let(:company) { create(:company, store: store) }

  it 'normalizes the email' do
    invitation = create(:company_invitation, company: company, email: ' Buyer@Example.COM ')

    expect(invitation.email).to eq('buyer@example.com')
  end

  it 'generates a token and a 30-day expiry' do
    invitation = create(:company_invitation, company: company)

    expect(invitation.token).to be_present
    expect(invitation.expires_at).to be_within(1.minute).of(30.days.from_now)
  end

  describe 'pending uniqueness' do
    it 'refuses a second pending invitation for the same email and node' do
      create(:company_invitation, company: company, email: 'buyer@example.com')

      expect(build(:company_invitation, company: company, email: 'buyer@example.com')).not_to be_valid
    end

    it 'permits re-inviting after revocation' do
      create(:company_invitation, company: company, email: 'buyer@example.com').revoke!

      expect(build(:company_invitation, company: company, email: 'buyer@example.com')).to be_valid
    end

    it 'permits re-inviting after expiry' do
      create(:company_invitation, company: company, email: 'buyer@example.com').update!(expires_at: 1.day.ago)

      expect(build(:company_invitation, company: company, email: 'buyer@example.com')).to be_valid
    end

    it 'permits the same email at another node' do
      create(:company_invitation, company: company, email: 'buyer@example.com')

      expect(build(:company_invitation, company: create(:company, store: store), email: 'buyer@example.com')).to be_valid
    end
  end

  describe '#revoke!' do
    it 'stamps the revocation' do
      invitation = create(:company_invitation, company: company)

      expect(invitation.revoke!).to be(true)
      expect(invitation.reload).to be_revoked
      expect(invitation).not_to be_pending
    end

    it 'refuses on an accepted invitation' do
      invitation = create(:company_invitation, company: company)
      invitation.update!(accepted_at: Time.current)

      expect(invitation.revoke!).to be(false)
    end
  end

  it 'stops being pending once expired' do
    invitation = create(:company_invitation, company: company)
    invitation.update!(expires_at: 1.minute.ago)

    expect(invitation).not_to be_pending
    expect(described_class.pending).not_to include(invitation)
  end
end
