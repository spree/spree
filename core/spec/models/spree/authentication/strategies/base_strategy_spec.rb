require 'spec_helper'

describe Spree::Authentication::Strategies::BaseStrategy do
  let(:params) { { email: 'user@example.com', password: 'secret' } }
  let(:request_env) { {} }
  let(:user_class) { Spree.user_class }

  subject(:strategy) do
    described_class.new(params: params, request_env: request_env, user_class: user_class)
  end

  describe '#initialize' do
    it 'sets params' do
      expect(strategy.params).to eq(params)
    end

    it 'sets request_env' do
      expect(strategy.request_env).to eq(request_env)
    end

    it 'sets user_class' do
      expect(strategy.user_class).to eq(user_class)
    end

    context 'when user_class is not provided' do
      subject(:strategy) do
        described_class.new(params: params, request_env: request_env)
      end

      it 'defaults to Spree.user_class' do
        expect(strategy.user_class).to eq(Spree.user_class)
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

  describe '#success' do
    let(:user) { create(:user) }

    it 'returns a successful Result' do
      result = strategy.send(:success, user)

      expect(result).to be_a(Spree::ServiceModule::Result)
      expect(result).to be_success
      expect(result.value).to eq(user)
    end
  end

  describe '#failure' do
    let(:message) { 'Authentication failed' }

    it 'returns a failed Result' do
      result = strategy.send(:failure, message)

      expect(result).to be_a(Spree::ServiceModule::Result)
      expect(result).not_to be_success
      expect(result.error).to eq(message)
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
  end

  describe '#find_or_create_user_from_oauth' do
    let(:provider) { 'google' }
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

    it 'passes the user_class' do
      admin_user_class = Spree.admin_user_class
      admin_strategy = described_class.new(
        params: params,
        request_env: request_env,
        user_class: admin_user_class
      )

      expect(Spree::UserIdentity).to receive(:find_or_create_from_oauth).with(
        hash_including(user_class: admin_user_class)
      )

      admin_strategy.send(:find_or_create_user_from_oauth,
                          provider: provider,
                          uid: uid,
                          info: info,
                          tokens: tokens)
    end
  end
end
