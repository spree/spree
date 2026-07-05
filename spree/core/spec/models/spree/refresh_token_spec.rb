require 'spec_helper'

RSpec.describe Spree::RefreshToken, type: :model do
  let(:user) { create(:user) }

  describe 'validations' do
    it 'requires a user' do
      token = described_class.new(expires_at: 30.days.from_now)
      token.valid?
      expect(token.errors[:user]).to be_present
    end

    it 'requires expires_at' do
      token = described_class.new(user: user)
      # has_secure_token generates token automatically
      token.valid?
      expect(token.errors[:expires_at]).to be_present
    end

    it 'auto-generates a token via has_secure_token' do
      token = described_class.create!(user: user, expires_at: 30.days.from_now)
      expect(token.token).to be_present
      expect(token.token.length).to be >= 24
    end
  end

  describe '.create_for' do
    it 'creates a refresh token for a user' do
      token = described_class.create_for(user)

      expect(token).to be_persisted
      expect(token.user).to eq(user)
      expect(token.token).to be_present
      expect(token.expires_at).to be > Time.current
    end

    it 'stores request env data' do
      token = described_class.create_for(user, request_env: {
        ip_address: '192.168.1.1',
        user_agent: 'Mozilla/5.0'
      })

      expect(token.ip_address).to eq('192.168.1.1')
      expect(token.user_agent).to eq('Mozilla/5.0')
    end

    it 'sets default 30-day expiry' do
      token = described_class.create_for(user)

      expect(token.expires_at).to be_within(1.minute).of(30.days.from_now)
    end
  end

  describe '#expired?' do
    it 'returns false for active tokens' do
      token = described_class.create_for(user)
      expect(token.expired?).to be false
    end

    it 'returns true for expired tokens' do
      token = described_class.create_for(user)
      token.update_column(:expires_at, 1.hour.ago)
      expect(token.expired?).to be true
    end
  end

  describe '#rotate!' do
    let!(:original_token) { described_class.create_for(user) }

    it 'destroys the original token' do
      original_id = original_token.id
      original_token.rotate!
      expect(described_class.find_by(id: original_id)).to be_nil
    end

    it 'creates a new token' do
      new_token = original_token.rotate!
      expect(new_token).to be_persisted
      expect(new_token.token).not_to eq(original_token.token)
    end

    it 'preserves the user' do
      new_token = original_token.rotate!
      expect(new_token.user).to eq(user)
    end

    it 'keeps total count the same' do
      expect {
        original_token.rotate!
      }.not_to change(described_class, :count)
    end

    it 'accepts new request env' do
      new_token = original_token.rotate!(request_env: {
        ip_address: '10.0.0.1',
        user_agent: 'NewBrowser/1.0'
      })
      expect(new_token.ip_address).to eq('10.0.0.1')
      expect(new_token.user_agent).to eq('NewBrowser/1.0')
    end
  end

  describe 'scopes' do
    let!(:active_token) { described_class.create_for(user) }
    let!(:expired_token) do
      t = described_class.create_for(user)
      t.update_column(:expires_at, 1.day.ago)
      t
    end

    describe '.active' do
      it 'returns only non-expired tokens' do
        expect(described_class.active).to include(active_token)
        expect(described_class.active).not_to include(expired_token)
      end
    end

    describe '.expired' do
      it 'returns only expired tokens' do
        expect(described_class.expired).to include(expired_token)
        expect(described_class.expired).not_to include(active_token)
      end
    end
  end

  describe '.revoke_all_for' do
    it 'deletes all tokens for a user' do
      described_class.create_for(user)
      described_class.create_for(user)

      expect {
        described_class.revoke_all_for(user)
      }.to change(described_class, :count).by(-2)
    end

    it 'does not delete tokens for other users' do
      other_user = create(:user)
      described_class.create_for(user)
      other_token = described_class.create_for(other_user)

      described_class.revoke_all_for(user)

      expect(described_class.find_by(id: other_token.id)).to be_present
    end
  end

  describe '.cleanup_expired!' do
    it 'deletes expired tokens' do
      active = described_class.create_for(user)
      expired = described_class.create_for(user)
      expired.update_column(:expires_at, 1.day.ago)

      described_class.cleanup_expired!

      expect(described_class.find_by(id: active.id)).to be_present
      expect(described_class.find_by(id: expired.id)).to be_nil
    end
  end

  describe 'prefixed_id' do
    it 'uses rt_ prefix' do
      token = described_class.create_for(user)
      expect(token.prefixed_id).to start_with('rt_')
    end
  end
end
