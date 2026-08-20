require 'spec_helper'

RSpec.describe Spree::Invitations::Accept do
  subject { described_class.call(invitation: invitation) }

  let(:invitation) { create(:invitation, invitee: invitee) }
  let(:invitee) { create(:admin_user, :without_admin_role) }

  it 'marks the invitation accepted and stamps the time' do
    expect { subject }.to change { invitation.reload.status }.from('pending').to('accepted')
    expect(invitation.accepted_at).to be_present
  end

  it 'grants the invitee the role they were invited to' do
    subject

    expect(invitation.role_user.user).to eq(invitee)
    expect(invitation.role_user.role).to eq(invitation.role)
  end

  it 'publishes invitation.accepted', events: true do
    allow(invitation).to receive(:publish_event).with(anything)
    expect(invitation).to receive(:publish_event).with('invitation.accepted')

    subject
  end

  context 'when already accepted' do
    before { invitation.update!(status: 'accepted') }

    it 'refuses' do
      expect(subject).not_to be_success
      expect(subject.error.value).to eq(:invitation_already_accepted)
    end
  end

  context 'when expired' do
    before { invitation.update_column(:expires_at, 1.day.ago) }

    it 'refuses and leaves the invitation pending' do
      expect(subject).not_to be_success
      expect(subject.error.value).to eq(:invitation_expired)
      expect(invitation.reload.status).to eq('pending')
    end
  end

  context 'without an invitee' do
    let(:invitee) { nil }

    it 'refuses' do
      expect(subject).not_to be_success
      expect(subject.error.value).to eq(:invitation_invitee_missing)
    end
  end
end
