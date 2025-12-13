# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::LegacyUserSerializer do
  let(:user) { create(:user) }

  subject { described_class.serialize(user) }

  describe '#as_json' do
    it 'inherits from UserSerializer' do
      expect(described_class.superclass).to eq(Spree::Events::UserSerializer)
    end

    it 'includes identity attributes' do
      expect(subject[:id]).to eq(user.id)
      expect(subject[:email]).to eq(user.email)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end

    it 'does not include sensitive data' do
      expect(subject).not_to have_key(:encrypted_password)
      expect(subject).not_to have_key(:password)
      expect(subject).not_to have_key(:spree_api_key)
    end
  end
end
