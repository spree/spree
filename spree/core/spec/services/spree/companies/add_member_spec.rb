require 'spec_helper'

describe Spree::Companies::AddMember do
  let(:store) { @default_store }
  let(:company) { create(:company, store: store) }

  context 'when the email matches an existing customer' do
    let!(:customer) { create(:customer, email: 'buyer@example.com') }

    it 'creates the membership immediately' do
      result = described_class.call(company: company, email: 'Buyer@Example.com')

      expect(result).to be_success
      expect(result.value).to be_a(Spree::CompanyMembership)
      expect(result.value.customer).to eq(customer)
    end

    it 'refuses a duplicate membership' do
      create(:company_membership, company: company, customer: customer)

      expect(described_class.call(company: company, email: 'buyer@example.com')).to be_failure
    end
  end

  context 'when the email is unknown' do
    it 'creates an invitation instead' do
      result = described_class.call(company: company, email: 'new@example.com')

      expect(result).to be_success
      expect(result.value).to be_a(Spree::CompanyInvitation)
      expect(result.value.email).to eq('new@example.com')
      expect(result.value.inviter).to be_nil
    end

    it 'records the inviting member' do
      inviter = create(:customer)

      result = described_class.call(company: company, email: 'new@example.com', inviter: inviter)

      expect(result.value.inviter).to eq(inviter)
    end

    it 'refuses a duplicate pending invitation' do
      create(:company_invitation, company: company, email: 'new@example.com')

      expect(described_class.call(company: company, email: 'new@example.com')).to be_failure
    end
  end
end
