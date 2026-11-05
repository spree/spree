require 'spec_helper'

describe Spree::Authentication::Strategies::BaseStrategy do
  let(:params) { { email: 'user@example.com', password: 'secret' } }
  let(:request_env) { {} }
  let(:user_class) { Spree.customer_class }

  subject(:strategy) do
    described_class.new(params: params, request_env: request_env, user_class: user_class)
  end

  describe '#initialize' do
    context 'when user_class is not provided' do
      subject(:strategy) do
        described_class.new(params: params, request_env: request_env)
      end

      it 'defaults to Spree.customer_class' do
        expect(strategy.user_class).to eq(Spree.customer_class)
      end
    end
  end

  describe '#authenticate' do
    it 'raises NotImplementedError' do
      expect { strategy.authenticate }.to raise_error(NotImplementedError, 'Subclass must implement #authenticate')
    end
  end

  describe '#provider' do
    it 'raises NotImplementedError' do
      expect { strategy.provider }.to raise_error(NotImplementedError, 'Subclass must implement #provider')
    end
  end

  describe '#find_user_by_email' do
    let!(:user) { create(:user, email: 'test@example.com') }

    it 'finds user by email' do
      result = strategy.send(:find_user_by_email, 'test@example.com')
      expect(result).to eq(user)
    end

    it 'returns nil when user not found' do
      result = strategy.send(:find_user_by_email, 'nonexistent@example.com')
      expect(result).to be_nil
    end

    it 'returns nil for a blank email rather than matching an arbitrary record' do
      expect(strategy.send(:find_user_by_email, nil)).to be_nil
      expect(strategy.send(:find_user_by_email, '')).to be_nil
    end

    # Email uniqueness is validated case-insensitively, so a differently-cased
    # address is the same account and must still log in.
    context 'when the stored email is capitalized' do
      let!(:user) { create(:user, email: 'Ada@Example.com') }

      it 'finds the user from a differently-cased email' do
        expect(strategy.send(:find_user_by_email, 'ada@example.com')).to eq(user)
        expect(strategy.send(:find_user_by_email, 'ADA@EXAMPLE.COM')).to eq(user)
      end
    end

    # Older data can hold two accounts differing only in case; the casing
    # typed must not choose between them.
    context 'when two accounts differ only in case' do
      let!(:user) { create(:user, email: 'ada@example.com') }

      before do
        # MySQL's default collation compares case-insensitively, so its unique
        # index can't hold such accounts, and the case cannot arise there.
        skip 'the email index is case-insensitive on MySQL' if ActiveRecord::Base.connection.adapter_name.match?(/mysql/i)

        other = create(:user, email: 'other@example.com')
        other.update_columns(email: 'Ada@Example.com')
      end

      it 'finds the same account whatever the casing' do
        expect(strategy.send(:find_user_by_email, 'Ada@Example.com')).to eq(strategy.send(:find_user_by_email, 'ada@example.com'))
      end
    end

    # An app may encrypt the column, deterministically so it can still be
    # looked up. SQL then only ever sees ciphertext.
    context 'when the app encrypts email' do
      let(:user_class) do
        stub_const('EncryptedEmailUser', Class.new(Spree.customer_class) do
          self.table_name = Spree.customer_class.table_name
          encrypts :email, deterministic: true, downcase: true
        end)
      end
      let!(:user) { user_class.create!(email: 'Ada@Example.com', password: 'secret123', password_confirmation: 'secret123') }

      it 'finds the user, whatever the case' do
        stored = user_class.connection.select_value(user_class.unscoped.where(id: user.id).select(:email).to_sql)
        expect(stored).not_to include('example.com')

        expect(strategy.send(:find_user_by_email, 'ada@example.com')).to eq(user)
        expect(strategy.send(:find_user_by_email, 'ADA@EXAMPLE.COM')).to eq(user)
      end
    end
  end

  describe '#find_or_create_user_from_oauth' do
    let(:provider) { 'email' }
    let(:uid) { '123456' }
    let(:info) { { email: 'oauth@example.com', first_name: 'OAuth', last_name: 'User' } }
    let(:tokens) { { access_token: 'token123' } }

    it 'delegates to UserIdentity.find_or_create_from_oauth' do
      expect(Spree::UserIdentity).to receive(:find_or_create_from_oauth).with(
        provider: provider,
        uid: uid,
        info: info,
        tokens: tokens,
        user_class: user_class
      )

      strategy.send(:find_or_create_user_from_oauth,
                    provider: provider,
                    uid: uid,
                    info: info,
                    tokens: tokens)
    end
  end
end
