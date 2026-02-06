require 'spec_helper'

describe Spree::Authentication::Strategies::GoogleStrategy do
  let(:id_token) { 'valid_google_id_token' }
  let(:params) { { id_token: id_token } }
  let(:request_env) { {} }

  subject(:strategy) do
    described_class.new(params: params, request_env: request_env)
  end

  let(:google_payload) do
    {
      'sub' => '123456789',
      'email' => 'google@example.com',
      'given_name' => 'John',
      'family_name' => 'Doe',
      'exp' => 1.hour.from_now.to_i
    }
  end

  describe '#provider' do
    it 'returns google' do
      expect(strategy.provider).to eq('google')
    end
  end

  describe '#authenticate' do
    context 'with valid Google token' do
      before do
        allow(strategy).to receive(:verify_google_token).with(id_token).and_return(google_payload)
      end

      context 'when user does not exist' do
        it 'returns successful result with new user' do
          expect do
            result = strategy.authenticate
            expect(result).to be_success
            expect(result.value).to be_a(Spree.user_class)
          end.to change(Spree.user_class, :count).by(1)
             .and change(Spree::UserIdentity, :count).by(1)
        end

        it 'creates user with correct attributes' do
          result = strategy.authenticate
          user = result.value

          expect(user.email).to eq('google@example.com')
          expect(user.first_name).to eq('John')
          expect(user.last_name).to eq('Doe')
        end

        it 'creates identity with correct attributes' do
          result = strategy.authenticate
          user = result.value
          identity = user.identities.first

          expect(identity.provider).to eq('google')
          expect(identity.uid).to eq('123456789')
          expect(identity.access_token).to eq(id_token)
          expect(identity.expires_at).to be_within(1.second).of(Time.at(google_payload['exp']))
        end
      end

      context 'when user already exists with identity' do
        let!(:user) { create(:user, email: 'google@example.com') }
        let!(:identity) do
          create(:user_identity, :google,
                 user: user,
                 uid: '123456789',
                 access_token: 'old_token')
        end

        it 'returns successful result with existing user' do
          expect do
            result = strategy.authenticate
            expect(result).to be_success
            expect(result.value).to eq(user)
          end.not_to change(Spree.user_class, :count)
        end

        it 'updates identity tokens' do
          strategy.authenticate

          identity.reload
          expect(identity.access_token).to eq(id_token)
          expect(identity.expires_at).to be_within(1.second).of(Time.at(google_payload['exp']))
        end
      end
    end

    context 'with invalid Google token' do
      before do
        allow(strategy).to receive(:verify_google_token).with(id_token).and_return(nil)
      end

      it 'returns failure result' do
        result = strategy.authenticate

        expect(result).not_to be_success
        expect(result.error).to eq('Invalid Google token')
      end
    end

    context 'when id_token is blank' do
      let(:params) { { id_token: '' } }

      it 'returns failure result' do
        result = strategy.authenticate

        expect(result).not_to be_success
        expect(result.error).to eq('Google ID token is required')
      end
    end

    context 'when id_token is missing' do
      let(:params) { {} }

      it 'returns failure result' do
        result = strategy.authenticate

        expect(result).not_to be_success
        expect(result.error).to eq('Google ID token is required')
      end
    end

    context 'when an error occurs during authentication' do
      before do
        allow(strategy).to receive(:verify_google_token).and_raise(StandardError, 'Token verification error')
      end

      it 'logs the error and returns failure' do
        expect(Rails.logger).to receive(:error).with(/GoogleStrategy authentication failed/)

        result = strategy.authenticate

        expect(result).not_to be_success
        expect(result.error).to eq('Google authentication failed')
      end
    end
  end

  describe '#verify_google_token' do
    let(:client_id) { 'test_client_id' }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('GOOGLE_CLIENT_ID').and_return(client_id)
    end

    context 'when Google::Auth::IDTokens is defined' do
      before do
        stub_const('Google::Auth::IDTokens', double)
      end

      it 'verifies token with Google library' do
        expect(Google::Auth::IDTokens).to receive(:verify_oidc).with(id_token, aud: client_id).and_return(google_payload)

        result = strategy.send(:verify_google_token, id_token)
        expect(result).to eq(google_payload)
      end

      context 'when verification fails' do
        before do
          allow(Google::Auth::IDTokens).to receive(:verify_oidc).and_raise(StandardError, 'Invalid token')
        end

        it 'logs error and returns nil' do
          expect(Rails.logger).to receive(:error).with(/Google token verification failed/)

          result = strategy.send(:verify_google_token, id_token)
          expect(result).to be_nil
        end
      end
    end

    context 'when Google::Auth::IDTokens is not defined' do
      it 'decodes token without verification and logs warning' do
        expect(Rails.logger).to receive(:warn).with(/Google token verification skipped/)
        allow(JWT).to receive(:decode).with(id_token, nil, false).and_return([google_payload])

        result = strategy.send(:verify_google_token, id_token)
        expect(result).to eq(google_payload)
      end
    end
  end

  describe '#google_client_id' do
    context 'when set in environment' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('GOOGLE_CLIENT_ID').and_return('env_client_id')
      end

      it 'returns environment variable value' do
        expect(strategy.send(:google_client_id)).to eq('env_client_id')
      end
    end

    context 'when set in credentials' do
      before do
        allow(ENV).to receive(:[]).with('GOOGLE_CLIENT_ID').and_return(nil)
        allow(Rails.application.credentials).to receive(:dig).with(:google, :client_id).and_return('credentials_client_id')
      end

      it 'returns credentials value' do
        expect(strategy.send(:google_client_id)).to eq('credentials_client_id')
      end
    end
  end

  describe 'with custom user class' do
    let(:admin_user_class) { Spree.admin_user_class }

    subject(:strategy) do
      described_class.new(params: params, request_env: request_env, user_class: admin_user_class)
    end

    before do
      allow(strategy).to receive(:verify_google_token).with(id_token).and_return(google_payload)
    end

    it 'creates user with admin user class' do
      result = strategy.authenticate

      expect(result).to be_success
      expect(result.value).to be_a(admin_user_class)
    end
  end
end
