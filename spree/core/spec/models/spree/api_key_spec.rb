require 'spec_helper'

RSpec.describe Spree::ApiKey, type: :model do
  let(:store) { create(:store) }
  let(:api_key) { create(:api_key, store: store) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(api_key).to be_valid
    end

    it 'requires a name' do
      api_key.name = nil
      expect(api_key).not_to be_valid
      expect(api_key.errors[:name]).to be_present
    end

    it 'requires a key_type' do
      api_key.key_type = nil
      expect(api_key).not_to be_valid
      expect(api_key.errors[:key_type]).to be_present
    end

    it 'requires key_type to be publishable or secret' do
      api_key.key_type = 'invalid'
      expect(api_key).not_to be_valid
      expect(api_key.errors[:key_type]).to be_present
    end

    it 'requires a store' do
      api_key.store = nil
      expect(api_key).not_to be_valid
    end

    it 'requires unique token for publishable keys' do
      duplicate = build(:api_key, :publishable, store: store, token: api_key.token)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:token]).to be_present
    end

    it 'validates token_digest presence for secret keys' do
      key = described_class.new(name: 'test', key_type: 'secret', store: store)
      # Skip the generate_token callback to test the validation directly
      key.instance_variable_set(:@_generate_token_called, true)
      described_class.skip_callback(:validation, :before, :generate_token, raise: false)
      expect(key).not_to be_valid
      expect(key.errors[:token_digest]).to be_present
    ensure
      described_class.set_callback(:validation, :before, :generate_token, on: :create)
    end

    it 'validates token_prefix presence for secret keys' do
      key = described_class.new(name: 'test', key_type: 'secret', store: store)
      key.token_digest = 'some_digest'
      described_class.skip_callback(:validation, :before, :generate_token, raise: false)
      expect(key).not_to be_valid
      expect(key.errors[:token_prefix]).to be_present
    ensure
      described_class.set_callback(:validation, :before, :generate_token, on: :create)
    end
  end

  describe 'token generation' do
    context 'publishable keys' do
      it 'generates token on create' do
        new_key = build(:api_key, :publishable, store: store, token: nil)
        new_key.save!
        expect(new_key.token).to be_present
      end

      it 'generates publishable key with pk_ prefix' do
        key = create(:api_key, :publishable, store: store)
        expect(key.token).to start_with('pk_')
      end

      it 'generates token of correct length' do
        expect(api_key.token.length).to eq(3 + Spree::ApiKey::TOKEN_LENGTH)
      end

      it 'returns token as plaintext_token' do
        key = create(:api_key, :publishable, store: store)
        expect(key.plaintext_token).to eq(key.token)
      end

      it 'does not set token_digest' do
        key = create(:api_key, :publishable, store: store)
        expect(key.token_digest).to be_nil
      end
    end

    context 'secret keys' do
      it 'generates secret key with sk_ prefix in plaintext_token' do
        key = create(:api_key, :secret, store: store)
        expect(key.plaintext_token).to start_with('sk_')
      end

      it 'does not store plaintext token in token column' do
        key = create(:api_key, :secret, store: store)
        expect(key.token).to be_nil
      end

      it 'stores token_digest as HMAC-SHA256 hex' do
        key = create(:api_key, :secret, store: store)
        expected_digest = OpenSSL::HMAC.hexdigest('SHA256', Rails.application.secret_key_base, key.plaintext_token)
        expect(key.token_digest).to eq(expected_digest)
      end

      it 'stores first 12 chars as token_prefix' do
        key = create(:api_key, :secret, store: store)
        expect(key.token_prefix).to eq(key.plaintext_token[0, 12])
      end

      it 'generates plaintext_token of correct length' do
        key = create(:api_key, :secret, store: store)
        expect(key.plaintext_token.length).to eq(3 + Spree::ApiKey::TOKEN_LENGTH)
      end

      it 'plaintext_token is not available on fresh load from database' do
        key = create(:api_key, :secret, store: store)
        reloaded_key = described_class.find(key.id)
        expect(reloaded_key.plaintext_token).to be_nil
      end
    end
  end

  describe 'scopes' do
    let!(:publishable_key) { create(:api_key, :publishable, store: store) }
    let!(:secret_key) { create(:api_key, :secret, store: store) }
    let!(:revoked_key) { create(:api_key, :revoked, store: store) }

    describe '.active' do
      it 'returns only non-revoked keys' do
        expect(described_class.active).to include(publishable_key, secret_key)
        expect(described_class.active).not_to include(revoked_key)
      end
    end

    describe '.revoked' do
      it 'returns only revoked keys' do
        expect(described_class.revoked).to include(revoked_key)
        expect(described_class.revoked).not_to include(publishable_key, secret_key)
      end
    end

    describe '.publishable' do
      it 'returns only publishable keys' do
        expect(described_class.publishable).to include(publishable_key)
        expect(described_class.publishable).not_to include(secret_key)
      end
    end

    describe '.secret' do
      it 'returns only secret keys' do
        expect(described_class.secret).to include(secret_key)
        expect(described_class.secret).not_to include(publishable_key)
      end
    end
  end

  describe '#publishable?' do
    it 'returns true for publishable key' do
      key = build(:api_key, :publishable)
      expect(key.publishable?).to be true
    end

    it 'returns false for secret key' do
      key = build(:api_key, :secret)
      expect(key.publishable?).to be false
    end
  end

  describe '#secret?' do
    it 'returns true for secret key' do
      key = build(:api_key, :secret)
      expect(key.secret?).to be true
    end

    it 'returns false for publishable key' do
      key = build(:api_key, :publishable)
      expect(key.secret?).to be false
    end
  end

  describe '#active?' do
    it 'returns true for non-revoked key' do
      expect(api_key.active?).to be true
    end

    it 'returns false for revoked key' do
      api_key.revoke!
      expect(api_key.active?).to be false
    end
  end

  describe '#revoke!' do
    it 'sets revoked_at timestamp' do
      expect { api_key.revoke! }.to change { api_key.revoked_at }.from(nil)
    end

    it 'sets revoked_by when user provided' do
      user = create(:user)
      api_key.revoke!(user)
      expect(api_key.revoked_by).to eq(user)
    end

    it 'marks key as inactive' do
      api_key.revoke!
      expect(api_key.active?).to be false
    end
  end

  describe '.find_by_secret_token' do
    it 'finds a secret key by its plaintext token' do
      key = create(:api_key, :secret, store: store)
      found = described_class.find_by_secret_token(key.plaintext_token)
      expect(found).to eq(key)
    end

    it 'returns nil for wrong token' do
      create(:api_key, :secret, store: store)
      expect(described_class.find_by_secret_token('sk_wrong_token')).to be_nil
    end

    it 'returns nil for blank token' do
      expect(described_class.find_by_secret_token('')).to be_nil
      expect(described_class.find_by_secret_token(nil)).to be_nil
    end

    it 'does not find revoked secret keys' do
      key = create(:api_key, :secret, store: store)
      plaintext = key.plaintext_token
      key.revoke!
      expect(described_class.find_by_secret_token(plaintext)).to be_nil
    end

    it 'does not find publishable keys' do
      key = create(:api_key, :publishable, store: store)
      expect(described_class.find_by_secret_token(key.token)).to be_nil
    end
  end

  describe 'associations' do
    it 'belongs to store' do
      expect(api_key.store).to eq(store)
    end

    it 'can have created_by' do
      user = create(:user)
      key = create(:api_key, store: store, created_by: user)
      expect(key.created_by).to eq(user)
    end

    it 'can have revoked_by' do
      user = create(:user)
      api_key.revoke!(user)
      expect(api_key.revoked_by).to eq(user)
    end
  end

  describe 'scopes (Admin API authorization)' do
    describe 'validation' do
      it 'requires scopes for secret keys' do
        key = build(:api_key, :secret, store: store, scopes: [])
        expect(key).not_to be_valid
        expect(key.errors[:scopes]).to be_present
      end

      it 'rejects unknown scopes for secret keys' do
        key = build(:api_key, :secret, store: store, scopes: ['read_orders', 'bogus_scope'])
        expect(key).not_to be_valid
        expect(key.errors[:scopes].join).to include('bogus_scope')
      end

      it 'accepts known scopes for secret keys' do
        key = build(:api_key, :secret, store: store, scopes: %w[read_orders write_customers])
        expect(key).to be_valid
      end

      it 'does not require scopes for publishable keys' do
        key = build(:api_key, :publishable, store: store, scopes: [])
        expect(key).to be_valid
      end

      it 'filters out blank values from the scopes array (sentinel from form hidden field)' do
        key = build(:api_key, :secret, store: store, scopes: ['', 'read_orders'])
        expect(key.scopes).to eq(['read_orders'])
        expect(key).to be_valid
      end
    end

    describe '#has_scope?' do
      it 'returns true for an exact scope match' do
        key = build(:api_key, :secret, store: store, scopes: ['read_orders'])
        expect(key.has_scope?('read_orders')).to be true
      end

      it 'returns false for a scope not granted' do
        key = build(:api_key, :secret, store: store, scopes: ['read_orders'])
        expect(key.has_scope?('write_orders')).to be false
        expect(key.has_scope?('read_customers')).to be false
      end

      it 'treats write_X as implying read_X' do
        key = build(:api_key, :secret, store: store, scopes: ['write_orders'])
        expect(key.has_scope?('read_orders')).to be true
        expect(key.has_scope?('write_orders')).to be true
      end

      it 'expands read_all to every read_* scope' do
        key = build(:api_key, :secret, store: store, scopes: ['read_all'])
        expect(key.has_scope?('read_orders')).to be true
        expect(key.has_scope?('read_customers')).to be true
        expect(key.has_scope?('write_orders')).to be false
      end

      it 'expands write_all to every read_* and write_* scope' do
        key = build(:api_key, :secret, store: store, scopes: ['write_all'])
        expect(key.has_scope?('read_orders')).to be true
        expect(key.has_scope?('write_orders')).to be true
        expect(key.has_scope?('write_customers')).to be true
      end
    end
  end
end
