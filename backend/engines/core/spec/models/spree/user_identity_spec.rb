require 'spec_helper'

describe Spree::UserIdentity, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:user).required }
  end

  describe 'validations' do
    subject { build(:user_identity) }

    it { is_expected.to validate_presence_of(:provider) }
    it { is_expected.to validate_presence_of(:uid) }
    it { is_expected.to validate_inclusion_of(:provider).in_array(Spree::UserIdentity::PROVIDERS) }

    describe 'uniqueness validation' do
      let(:user) { create(:user) }
      let!(:existing_identity) do
        create(:user_identity, user: user, provider: 'google', uid: '12345')
      end

      it 'validates uniqueness of uid scoped to provider and user_type' do
        duplicate = build(:user_identity, user: user, provider: 'google', uid: '12345')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:uid]).to include('has already been taken')
      end

      it 'allows same uid for different providers' do
        different_provider = build(:user_identity, user: user, provider: 'facebook', uid: '12345')
        expect(different_provider).to be_valid
      end

      it 'allows same uid for different user types' do
        stub_const('Spree::AdminUser', Class.new(Spree.user_class))

        different_user_type = build(:user_identity, user_type: 'Spree::AdminUser', user_id: user.id, provider: 'google', uid: '12345')
        expect(different_user_type).to be_valid
      end
    end
  end

  describe '.find_or_create_from_oauth' do
    let(:provider) { 'google' }
    let(:uid) { '123456789' }
    let(:info) do
      {
        email: 'user@example.com',
        first_name: 'John',
        last_name: 'Doe'
      }
    end
    let(:tokens) do
      {
        access_token: 'access_token_123',
        refresh_token: 'refresh_token_456',
        expires_at: 1.hour.from_now
      }
    end

    context 'when identity does not exist' do
      it 'creates a new user and identity' do
        expect do
          described_class.find_or_create_from_oauth(
            provider: provider,
            uid: uid,
            info: info,
            tokens: tokens
          )
        end.to change(Spree.user_class, :count).by(1)
           .and change(described_class, :count).by(1)
      end

      it 'sets user attributes from info' do
        user = described_class.find_or_create_from_oauth(
          provider: provider,
          uid: uid,
          info: info,
          tokens: tokens
        )

        expect(user.email).to eq('user@example.com')
        expect(user.first_name).to eq('John')
        expect(user.last_name).to eq('Doe')
      end

      it 'creates identity with tokens' do
        user = described_class.find_or_create_from_oauth(
          provider: provider,
          uid: uid,
          info: info,
          tokens: tokens
        )

        identity = user.identities.first
        expect(identity.provider).to eq('google')
        expect(identity.uid).to eq('123456789')
        expect(identity.access_token).to eq('access_token_123')
        expect(identity.refresh_token).to eq('refresh_token_456')
        expect(identity.expires_at).to be_within(1.second).of(tokens[:expires_at])
      end

      it 'generates temporary email if email is missing' do
        user = described_class.find_or_create_from_oauth(
          provider: provider,
          uid: uid,
          info: info.except(:email),
          tokens: tokens
        )

        expect(user.email).to eq('google-123456789@temporary.example.com')
      end

      it 'uses custom user class when provided' do
        admin_user_class = Spree.admin_user_class

        user = described_class.find_or_create_from_oauth(
          provider: provider,
          uid: uid,
          info: info,
          tokens: tokens,
          user_class: admin_user_class
        )

        expect(user).to be_a(admin_user_class)
      end
    end

    context 'when identity already exists' do
      let!(:user) { create(:user, email: 'existing@example.com') }
      let!(:identity) do
        create(:user_identity,
               user: user,
               provider: provider,
               uid: uid,
               access_token: 'old_token',
               refresh_token: 'old_refresh')
      end

      it 'does not create a new user' do
        expect do
          described_class.find_or_create_from_oauth(
            provider: provider,
            uid: uid,
            info: info,
            tokens: tokens
          )
        end.not_to change(Spree.user_class, :count)
      end

      it 'returns the existing user' do
        result = described_class.find_or_create_from_oauth(
          provider: provider,
          uid: uid,
          info: info,
          tokens: tokens
        )

        expect(result).to eq(user)
      end

      it 'updates identity tokens' do
        described_class.find_or_create_from_oauth(
          provider: provider,
          uid: uid,
          info: info,
          tokens: tokens
        )

        identity.reload
        expect(identity.access_token).to eq('access_token_123')
        expect(identity.refresh_token).to eq('refresh_token_456')
        expect(identity.expires_at).to be_within(1.second).of(tokens[:expires_at])
      end

      it 'updates identity info' do
        described_class.find_or_create_from_oauth(
          provider: provider,
          uid: uid,
          info: { email: 'new@example.com', first_name: 'Jane' },
          tokens: tokens
        )

        identity.reload
        expect(identity.info).to include('email' => 'new@example.com', 'first_name' => 'Jane')
      end
    end
  end

  describe '.create_user_from_oauth' do
    it 'creates user with random password' do
      user = described_class.create_user_from_oauth(
        provider: 'google',
        uid: '123',
        info: { email: 'test@example.com', first_name: 'Test', last_name: 'User' },
        tokens: {}
      )

      expect(user.persisted?).to be_truthy
      expect(user.valid?).to be_truthy
      expect(user.password).to be_present
    end
  end

  describe '.generate_temp_email' do
    it 'generates email with provider and uid' do
      email = described_class.generate_temp_email('google', '123456')
      expect(email).to eq('google-123456@temporary.example.com')
    end
  end

  describe '#expired?' do
    context 'when expires_at is nil' do
      subject { build(:user_identity, expires_at: nil) }

      it { is_expected.not_to be_expired }
    end

    context 'when expires_at is in the future' do
      subject { build(:user_identity, expires_at: 1.hour.from_now) }

      it { is_expected.not_to be_expired }
    end

    context 'when expires_at is in the past' do
      subject { build(:user_identity, expires_at: 1.hour.ago) }

      it { is_expected.to be_expired }
    end
  end
end
