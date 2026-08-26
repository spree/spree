require 'spec_helper'
require 'email_spec'

describe Spree::CompanyMailer, type: :mailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  let(:store) { @default_store }
  let(:company) { create(:company, store: store, name: 'Acme Industrial') }
  let(:invitation) { create(:company_invitation, company: company, email: 'new@example.com') }

  describe '#invitation_email' do
    it 'sends to the invited email with the store-prefixed subject' do
      message = described_class.invitation_email(invitation)

      expect(message.to).to eq(['new@example.com'])
      expect(message.from).to eq([store.mail_from_address])
      expect(message.subject).to include(store.name)
      expect(message.subject).to include('Acme Industrial')
    end

    # The queue can sit for minutes; an invitation revoked in that window must
    # not still arrive carrying a working token.
    it 'sends nothing when the invitation stopped being pending after enqueue' do
      invitation.revoke!

      expect {
        described_class.invitation_email(invitation.id).deliver_now
      }.not_to change { ActionMailer::Base.deliveries.count }
    end

    it 'links to the storefront acceptance page with the token appended' do
      message = described_class.invitation_email(invitation)

      expect(message).to have_body_text("token=#{invitation.token}")
      expect(message).to have_body_text('company-invitation')
    end
  end
end
