require 'spec_helper'

RSpec.describe Spree::InvitationMailer, type: :mailer do
  let(:store) { @default_store }
  let(:inviter) { create(:admin_user) }
  let(:invitation) { create(:invitation, email: 'invited@example.com', inviter: inviter, resource: store) }
  let(:spree) { Spree::Core::Engine.routes.url_helpers }

  before do
    allow(spree).to receive(:admin_invitation_url).and_return("http://test.com/admin/invitations/#{invitation.id}?token=#{invitation.token}")
  end

  describe '#invitation_email' do
    subject(:mail) { described_class.invitation_email(invitation) }

    it 'renders the subject' do
      expect(mail.subject).to eq(
        Spree.t('invitation_mailer.invitation_email.subject', resource_name: store.name)
      )
    end

    it 'sends to the correct recipient' do
      expect(mail.to).to eq([invitation.email])
    end

    it 'sends from the store mail from address' do
      expect(mail.from).to eq([store.mail_from_address])
    end

    it 'sets reply-to as the store mail from address' do
      expect(mail.reply_to).to eq([store.mail_from_address])
    end

    it 'includes the invitation link in the body' do
      expect(mail.body.encoded).to include("http://test.com/admin/invitations/#{invitation.id}?token=#{invitation.token}")
    end
  end

  describe '#invitation_accepted' do
    subject(:mail) { described_class.invitation_accepted(invitation) }

    let(:invitee) { create(:admin_user, first_name: 'John', last_name: 'Doe') }

    before do
      allow(invitation).to receive(:invitee).and_return(invitee)
    end

    it 'renders the subject' do
      expect(mail.subject).to eq(
        Spree.t('invitation_mailer.invitation_accepted.subject', invitee_name: invitee.name, resource_name: store.name)
      )
    end

    it 'includes the invitee name in the body' do
      expect(mail.body.encoded).to include(invitee.name)
    end

    it 'sends to the correct recipient' do
      expect(mail.to).to eq([inviter.email])
    end

    it 'sends from the store mail from address' do
      expect(mail.from).to eq([store.mail_from_address])
    end

    it 'sets reply-to as the store mail from address' do
      expect(mail.reply_to).to eq([store.mail_from_address])
    end
  end
end
