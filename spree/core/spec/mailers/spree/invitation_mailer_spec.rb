require 'spec_helper'

RSpec.describe Spree::InvitationMailer, type: :mailer do
  let(:store) { @default_store }
  let(:inviter) { create(:admin_user) }
  let(:invitation) { create(:invitation, email: 'invited@example.com', inviter: inviter, resource: store, skip_email: true) }
  let(:spree) { Spree::Core::Engine.routes.url_helpers }
  let(:legacy_admin_url) { "http://test.com/admin/invitations/#{invitation.id}?token=#{invitation.token}" }
  let(:spa_acceptance_url) { Rails.application.routes.url_helpers.admin_invitation_acceptance_url(invitation) }

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

    # The link target depends on whether the legacy `spree_admin` Rails gem
    # is loaded — when present its `admin_invitation_url` route helper takes
    # precedence so existing deployments keep working unchanged. When
    # absent (the 6.0 SPA-only setup) the mailer falls back to the
    # `admin_invitation_acceptance` direct route, which points at the SPA.
    context 'when the legacy spree_admin gem is installed' do
      before do
        allow(spree).to receive(:respond_to?).and_call_original
        allow(spree).to receive(:respond_to?).with(:admin_invitation_url).and_return(true)
        allow(spree).to receive(:admin_invitation_url).and_return(legacy_admin_url)
      end

      it 'uses spree.admin_invitation_url for the accept link' do
        expect(mail.body.encoded).to include(Spree.t(:accept))
        expect(mail.body.encoded).to include(legacy_admin_url)
        expect(mail.body.encoded).not_to include(spa_acceptance_url)
      end
    end

    context 'when the legacy spree_admin gem is not installed' do
      before do
        allow(spree).to receive(:respond_to?).and_call_original
        allow(spree).to receive(:respond_to?).with(:admin_invitation_url).and_return(false)
        Spree::Config[:admin_url] = 'https://admin.example.com'
      end

      after do
        Spree::Config[:admin_url] = nil
      end

      it 'uses the admin_invitation_acceptance helper for the accept link' do
        expect(mail.body.encoded).to include(Spree.t(:accept))
        expect(mail.body.encoded).to include(spa_acceptance_url)
        expect(mail.body.encoded).not_to include(legacy_admin_url)
      end

      it 'honors Spree::Config[:admin_url] in the rendered URL' do
        expect(mail.body.encoded).to include(
          "https://admin.example.com/accept-invitation/#{invitation.prefixed_id}"
        )
      end
    end

    context 'when neither the legacy gem nor admin_url is configured' do
      before do
        allow(spree).to receive(:respond_to?).and_call_original
        allow(spree).to receive(:respond_to?).with(:admin_invitation_url).and_return(false)
      end

      # Falls through to the store's storefront URL — keeps the dummy/test
      # app + all-in-one installs working without any Spree::Config setup.
      it 'falls back to the storefront URL' do
        expect(mail.body.encoded).to match(%r{accept-invitation/#{invitation.prefixed_id}\?token=#{invitation.token}})
      end
    end
  end

  describe '#invitation_accepted' do
    subject(:mail) { described_class.invitation_accepted(invitation) }

    let(:invitee) { create(:admin_user, first_name: 'John', last_name: 'Doe') }

    before do
      invitation.update!(invitee: invitee)
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
