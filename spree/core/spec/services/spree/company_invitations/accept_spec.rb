require 'spec_helper'

describe Spree::CompanyInvitations::Accept do
  let(:store) { @default_store }
  let(:company) { create(:company, store: store) }
  let(:invitation) { create(:company_invitation, company: company, email: 'new@example.com') }
  let(:invited_customer) { create(:customer, email: 'new@example.com') }

  context 'with a registration payload' do
    it 'creates the customer through the registration workflow and lands as a membership' do
      result = described_class.call(
        invitation: invitation,
        customer_attributes: { password: 'Sup3r-secret', password_confirmation: 'Sup3r-secret',
                               first_name: 'Ada' }
      )

      expect(result).to be_success
      membership = result.value
      expect(membership.company).to eq(company)
      # The account is created with the invited email, never a client-supplied one.
      expect(membership.customer.email).to eq('new@example.com')
      expect(invitation.reload).to be_accepted
      expect(invitation.customer).to eq(membership.customer)
    end

    it 'fails when registration fails and leaves the invitation pending' do
      result = described_class.call(invitation: invitation, customer_attributes: { password: 'short' })

      expect(result).to be_failure
      expect(invitation.reload).to be_pending
    end
  end

  context 'with an authenticated customer' do
    it 'binds the invitation to the customer it was addressed to' do
      customer = create(:customer, email: 'new@example.com')

      result = described_class.call(invitation: invitation, customer: customer)

      expect(result).to be_success
      expect(result.value.customer).to eq(customer)
      expect(invitation.reload.customer).to eq(customer)
    end

    it 'matches the email however it was capitalised on signup' do
      customer = create(:customer, email: 'New@Example.com')

      expect(described_class.call(invitation: invitation, customer: customer)).to be_success
    end

    # The token names one person. Spending it from another signed-in account
    # would hand that account standing over the company — buying, reading the
    # subtree's orders, revoking the other members' invitations.
    it 'refuses a customer the invitation was not addressed to' do
      result = described_class.call(invitation: invitation, customer: create(:customer))

      expect(result).to be_failure
      expect(invitation.reload).to be_pending
      expect(company.memberships.reload).to be_empty
    end

    it 'is idempotent for an existing member' do
      customer = create(:customer, email: 'new@example.com')
      membership = create(:company_membership, company: company, customer: customer)

      result = described_class.call(invitation: invitation, customer: customer)

      expect(result).to be_success
      expect(result.value).to eq(membership)
      expect(invitation.reload).to be_accepted
    end
  end

  it 'refuses an expired invitation' do
    invitation.update!(expires_at: 1.day.ago)

    expect(described_class.call(invitation: invitation, customer: invited_customer)).to be_failure
  end

  it 'refuses a revoked invitation' do
    invitation.revoke!

    expect(described_class.call(invitation: invitation, customer: invited_customer)).to be_failure
  end

  it 'refuses spending the token twice' do
    described_class.call(invitation: invitation, customer: invited_customer)

    expect(described_class.call(invitation: invitation, customer: invited_customer)).to be_failure
  end
end
