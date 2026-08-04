require 'spec_helper'

describe Spree::Authentication::Strategies::OidcStrategy do
  let(:issuer) { 'https://idp.example.com' }
  let(:factory) do
    described_class.configure(
      issuer: issuer,
      client_id: 'client-id',
      client_secret: 'client-secret',
      redirect_uri: 'https://shop.example.com/api/v3/admin/auth/callback/entra',
      label: 'Microsoft Entra ID'
    )
  end

  describe '.configure' do
    it 'builds a factory describing itself as a redirect provider' do
      expect(factory.kind).to eq(:redirect)
      expect(factory.label).to eq('Microsoft Entra ID')
    end

    it 'raises when a required option is missing' do
      expect {
        described_class.configure(issuer: issuer, client_id: nil, client_secret: 's', redirect_uri: 'u')
      }.to raise_error(ArgumentError, /client_id/)
    end

    it 'normalizes a trailing slash on the issuer so discovery URLs stay well-formed' do
      configured = described_class.configure(
        issuer: 'https://idp.example.com/',
        client_id: 'c', client_secret: 's', redirect_uri: 'u'
      )

      expect(configured.config[:issuer]).to eq('https://idp.example.com')
    end
  end

  describe '#build' do
    it 'returns a strategy carrying the configured provider settings' do
      strategy = factory.build(params: { code: 'abc' }, request_env: {}, user_class: Spree.admin_user_class)

      expect(strategy).to be_a(described_class)
      expect(strategy.user_class).to eq(Spree.admin_user_class)
      expect(strategy.config[:client_id]).to eq('client-id')
    end
  end

  describe '#authenticate' do
    it 'refuses direct credential login' do
      result = factory.build(params: {}, request_env: {}).authenticate

      expect(result).not_to be_success
    end
  end

  describe '#callback' do
    let(:strategy) { factory.build(params: params, request_env: {}, user_class: Spree.admin_user_class) }

    # UserIdentity validates `provider` against the registered strategy keys, so
    # identity linking only works for a provider that is actually registered.
    before { Spree.admin_authentication_strategies.add(:entra, factory) }
    after { Spree.admin_authentication_strategies.remove(:entra) }

    context 'without an authorization code' do
      let(:params) { { provider: 'entra' } }

      it 'fails' do
        expect(strategy.callback).not_to be_success
      end
    end

    context 'with verified claims' do
      let(:params) { { provider: 'entra', code: 'auth-code' } }
      let(:claims) do
        { 'sub' => 'idp-subject-1', 'email' => admin.email, 'email_verified' => 'true', 'name' => 'Ada' }
      end
      let!(:admin) { create(:admin_user, email: 'ada@example.com') }

      before do
        allow(strategy).to receive(:exchange_code_for_tokens).and_return('id_token' => 'signed-token')
        allow(strategy).to receive(:verify_id_token).with('signed-token').and_return(claims)
      end

      it 'links the identity to the existing admin and signs them in' do
        result = strategy.callback

        expect(result).to be_success
        expect(result.value).to eq(admin)
        expect(admin.identities.find_by(provider: 'entra', uid: 'idp-subject-1')).to be_present
      end

      it 'signs in through an already-linked identity without creating a second one' do
        strategy.callback
        second = factory.build(params: params, request_env: {}, user_class: Spree.admin_user_class)
        allow(second).to receive(:exchange_code_for_tokens).and_return('id_token' => 'signed-token')
        allow(second).to receive(:verify_id_token).and_return(claims)

        expect { second.callback }.not_to change(Spree::UserIdentity, :count)
      end

      # The models normalize email with squish but never downcase, so the match
      # has to be case-insensitive on both sides or linking silently fails on a
      # case-sensitive database.
      context 'when the stored email differs only by case' do
        let!(:admin) { create(:admin_user, email: 'Ada@Example.com') }
        let(:claims) do
          { 'sub' => 'idp-subject-1', 'email' => 'ada@example.com', 'email_verified' => 'true' }
        end

        it 'still links the identity to the existing admin' do
          result = strategy.callback

          expect(result).to be_success
          expect(result.value).to eq(admin)
        end
      end

      # Entra omits email_verified for work accounts, so the claim's absence must
      # be a configurable decision rather than an implicit yes or no.
      context 'when the provider omits the email_verified claim' do
        let(:claims) { { 'sub' => 'idp-subject-1', 'email' => admin.email } }

        it 'refuses to link by default' do
          result = strategy.callback

          expect(result).not_to be_success
          expect(admin.identities).to be_empty
        end

        context 'and the provider is configured to trust its directory' do
          let(:factory) do
            described_class.configure(
              issuer: issuer,
              client_id: 'client-id',
              client_secret: 'client-secret',
              redirect_uri: 'https://shop.example.com/api/v3/admin/auth/callback/entra',
              label: 'Microsoft Entra ID',
              trust_unverified_email: true
            )
          end

          it 'links the identity to the existing admin' do
            result = strategy.callback

            expect(result).to be_success
            expect(result.value).to eq(admin)
          end

          # A present "false" is an explicit denial and outranks the configuration.
          it 'still refuses an explicitly unverified email' do
            allow(strategy).to receive(:verify_id_token).and_return(claims.merge('email_verified' => 'false'))

            expect(strategy.callback).not_to be_success
          end
        end
      end

      context 'when the email is not verified by the provider' do
        let(:claims) do
          { 'sub' => 'idp-subject-1', 'email' => admin.email, 'email_verified' => 'false' }
        end

        # Matching on an unverified claim would let anyone who can set their IdP
        # email to a staff address take over that account.
        it 'refuses to claim the existing account' do
          result = strategy.callback

          expect(result).not_to be_success
          expect(admin.identities).to be_empty
        end
      end

      context 'when no account matches the verified email' do
        let(:claims) do
          { 'sub' => 'idp-subject-2', 'email' => 'stranger@example.com', 'email_verified' => 'true' }
        end

        it 'rejects rather than auto-provisioning an admin' do
          expect { expect(strategy.callback).not_to be_success }.not_to change(Spree.admin_user_class, :count)
        end
      end
    end

    context 'when the provider call raises' do
      let(:params) { { provider: 'entra', code: 'auth-code' } }

      it 'returns a failure instead of propagating the error' do
        allow(strategy).to receive(:exchange_code_for_tokens).and_raise(StandardError, 'boom')

        expect(strategy.callback).not_to be_success
      end
    end
  end

  describe '#authorization_url' do
    before do
      allow_any_instance_of(described_class).to receive(:discovery_document).and_return(
        'authorization_endpoint' => "#{issuer}/authorize"
      )
    end

    it 'includes the client, redirect URI and CSRF state' do
      url = factory.authorization_url(state: 'csrf-token')

      expect(url).to start_with("#{issuer}/authorize?")
      expect(url).to include('client_id=client-id')
      expect(url).to include('state=csrf-token')
      expect(url).to include('response_type=code')
    end
  end
end
