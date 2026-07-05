# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::InvitationSerializer do
  let(:store) { @default_store }
  let(:invitation) { create(:invitation) }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(invitation, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id email status resource_type resource_id inviter_type inviter_id
      invitee_type invitee_id role_id expires_at accepted_at created_at updated_at
    ])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(invitation.prefixed_id)
  end

  it 'returns prefixed inviter_id' do
    expect(subject['inviter_id']).to eq(invitation.inviter.prefixed_id)
  end
end
