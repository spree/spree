# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::InvitationSerializer do
  let(:invitation) { create(:invitation) }

  subject { described_class.serialize(invitation) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(invitation.prefixed_id)
      expect(subject[:email]).to eq(invitation.email)
    end

    it 'includes status as string' do
      expect(subject[:status]).to be_a(String)
    end

    it 'includes resource polymorphic reference' do
      expect(subject[:resource_type]).to eq(invitation.resource_type)
      expect(subject[:resource_id]).to eq(invitation.resource&.prefixed_id)
    end

    it 'includes inviter polymorphic reference' do
      expect(subject[:inviter_type]).to eq(invitation.inviter_type)
      expect(subject[:inviter_id]).to eq(invitation.inviter&.prefixed_id)
    end

    it 'includes invitee polymorphic reference' do
      expect(subject).to have_key(:invitee_type)
      expect(subject).to have_key(:invitee_id)
    end

    it 'includes role_id' do
      expect(subject[:role_id]).to eq(invitation.role&.prefixed_id)
    end

    it 'includes dates' do
      expect(subject).to have_key(:expires_at)
      expect(subject).to have_key(:accepted_at)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end
  end
end
