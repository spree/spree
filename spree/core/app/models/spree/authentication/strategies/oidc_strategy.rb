require 'net/http'

module Spree
  module Authentication
    module Strategies
      # Generic OpenID Connect strategy — the reference SSO provider.
      #
      # Configured by issuer rather than by vendor, so one class covers Microsoft
      # Entra ID, Okta, Google Workspace, Keycloak and Auth0. Endpoints and signing
      # keys are read from the issuer's discovery document
      # (+.well-known/openid-configuration+), so nothing vendor-specific is hardcoded.
      #
      # Registered as a configured factory, which lets the same class back several
      # providers with different issuers:
      #
      #   Spree.admin_authentication_strategies.add(
      #     :entra,
      #     Spree::Authentication::Strategies::OidcStrategy.configure(
      #       issuer: 'https://login.microsoftonline.com/<tenant>/v2.0',
      #       client_id: ENV['ENTRA_CLIENT_ID'],
      #       client_secret: ENV['ENTRA_CLIENT_SECRET'],
      #       redirect_uri: 'https://shop.example.com/api/v3/admin/auth/callback/entra',
      #       label: 'Microsoft Entra ID'
      #     )
      #   )
      class OidcStrategy < BaseStrategy
        # Configured registry entry. Holds provider settings and builds a strategy
        # instance per request, mirroring the class-level interface the registry
        # reads for discovery (+kind+, +label+, +authorization_url+).
        class Factory
          attr_reader :config

          def initialize(config)
            @config = config
          end

          def build(params:, request_env:, user_class: nil)
            OidcStrategy.new(
              params: params,
              request_env: request_env,
              user_class: user_class,
              config: config
            )
          end

          def kind
            :redirect
          end

          def label
            config[:label]
          end

          # Reuses one request-less strategy for URL building. The factory lives
          # for the process lifetime, so its discovery-document memo survives
          # across requests — a fresh instance per call would re-read the cache
          # (a DB query under solid_cache) on every login-page load.
          def authorization_url(state:)
            @url_builder ||= OidcStrategy.new(params: {}, request_env: {}, config: config)
            @url_builder.authorization_url(state: state)
          end
        end

        REQUIRED_OPTIONS = %i[issuer client_id client_secret redirect_uri].freeze

        # Builds a registry entry for one identity provider.
        #
        # @param issuer [String] OIDC issuer URL (discovery is read from it)
        # @param client_id [String]
        # @param client_secret [String]
        # @param redirect_uri [String] must match the value registered with the IdP
        # @param label [String] name shown on the dashboard login button
        # @param scope [String] space-separated scopes; must include +openid+
        # @return [Factory]
        def self.configure(issuer:, client_id:, client_secret:, redirect_uri:, label: nil, scope: 'openid email profile')
          config = {
            issuer: issuer.to_s.chomp('/'),
            client_id: client_id,
            client_secret: client_secret,
            redirect_uri: redirect_uri,
            label: label,
            scope: scope
          }

          missing = REQUIRED_OPTIONS.select { |option| config[option].blank? }
          raise ArgumentError, "OidcStrategy is missing required options: #{missing.join(', ')}" if missing.any?

          # Derived once — the issuer is fixed for the life of a registration.
          config[:cache_key_prefix] = "spree/oidc/#{Digest::SHA256.hexdigest(config[:issuer])}"

          Factory.new(config)
        end

        attr_reader :config

        def initialize(params:, request_env:, user_class: nil, config: {})
          super(params: params, request_env: request_env, user_class: user_class)
          @config = config
        end

        def provider
          :oidc
        end

        # Where to send the browser to begin login.
        # @param state [String] opaque CSRF token echoed back to the callback
        # @return [String]
        def authorization_url(state:)
          query = {
            client_id: config[:client_id],
            response_type: 'code',
            scope: config[:scope],
            redirect_uri: config[:redirect_uri],
            state: state
          }

          "#{discovery_document.fetch('authorization_endpoint')}?#{query.to_query}"
        end

        # Password login is not available through an OIDC provider — the browser
        # redirect is the only entry point.
        def authenticate
          failure(Spree.t('errors.messages.oidc_requires_redirect'))
        end

        # Completes the login started by +#authorization_url+: exchanges the
        # authorization code for an ID token, verifies it, and resolves the claims
        # to a user.
        # @return [Spree::ServiceModule::Result]
        def callback
          code = params[:code]
          return authentication_failure(Spree.t('errors.messages.oidc_missing_code')) if code.blank?

          claims = verify_id_token(exchange_code_for_tokens(code).fetch('id_token'))
          resolve_user(claims)
        rescue StandardError => e
          Rails.logger.error("[Spree] OIDC callback failed for #{config[:label] || config[:issuer]}: #{e.message}")
          authentication_failure(Spree.t('errors.messages.oidc_authentication_failed'))
        end

        # True when the last +#callback+ failed because no account here is
        # authorized for an otherwise-authenticated IdP subject, as opposed to a
        # technical failure (missing code, token verification). The two carry
        # different error codes and very different advice for the person.
        # @return [Boolean]
        def account_not_provisioned?
          @account_not_provisioned.present?
        end

        private

        # Resolves verified IdP claims to a user, in three steps:
        #
        # 1. a known identity logs in;
        # 2. an existing account with the same **verified** email adopts the
        #    identity — this is what lets a shop switch on SSO without making
        #    existing staff log in with a password first;
        # 3. anything else is rejected. Admin accounts never auto-provision, or
        #    every member of a corporate tenant would become store staff.
        def resolve_user(claims)
          subject = claims['sub']
          return authentication_failure(Spree.t('errors.messages.oidc_authentication_failed')) if subject.blank?

          identity = Spree::UserIdentity.find_by(
            provider: registry_key,
            uid: subject,
            user_type: user_class.name
          )
          return success(identity.user) if identity

          user = find_linkable_user(claims)
          return not_provisioned_failure if user.nil?

          user.identities.create!(provider: registry_key, uid: subject, info: identity_info(claims))
          success(user)
        end

        def authentication_failure(message)
          @account_not_provisioned = false
          failure(message)
        end

        def not_provisioned_failure
          @account_not_provisioned = true
          failure(Spree.t('errors.messages.oidc_account_not_provisioned'))
        end

        # Only an email the provider asserts as verified may claim an existing
        # account. Matching on an unverified claim would let anyone who can set
        # their IdP email to a staff address take that account over.
        def find_linkable_user(claims)
          return nil unless claims['email_verified'].to_s == 'true'

          email = claims['email']
          return nil if email.blank?

          # Compared case-insensitively on both sides: the models normalize email
          # with +squish+ but never downcase, so a stored "Ada@Example.com" would
          # not match a lowercased claim on a case-sensitive database.
          user_class.find_by(user_class.arel_table[:email].lower.eq(email.to_s.downcase))
        end

        def identity_info(claims)
          claims.slice('email', 'name', 'given_name', 'family_name', 'picture')
        end

        # The key this provider is registered under — used as UserIdentity#provider
        # so two OIDC providers on one store stay distinct.
        def registry_key
          params[:provider].presence || provider.to_s
        end

        def exchange_code_for_tokens(code)
          response = post_form(
            discovery_document.fetch('token_endpoint'),
            grant_type: 'authorization_code',
            code: code,
            redirect_uri: config[:redirect_uri],
            client_id: config[:client_id],
            client_secret: config[:client_secret]
          )

          raise "token endpoint returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

          JSON.parse(response.body)
        end

        # Verifies signature, issuer and audience. Skipping any of these would let
        # a token minted for another application authenticate here.
        def verify_id_token(id_token)
          claims, = JWT.decode(
            id_token,
            nil,
            true,
            algorithms: discovery_document.fetch('id_token_signing_alg_values_supported', ['RS256']),
            iss: config[:issuer],
            verify_iss: true,
            aud: config[:client_id],
            verify_aud: true,
            jwks: jwks
          )

          claims
        end

        # A loader proc rather than a fetched set: the jwt gem re-invokes it with
        # +invalidate: true+ when a token's key id is missing from the cached set,
        # so signing keys are cached like the discovery document yet still pick up
        # provider key rotation on the next login.
        def jwks
          lambda do |options|
            Rails.cache.delete(jwks_cache_key) if options[:invalidate]

            JWT::JWK::Set.new(
              Rails.cache.fetch(jwks_cache_key, expires_in: 12.hours) do
                JSON.parse(http_get(discovery_document.fetch('jwks_uri')))
              end
            )
          end
        end

        def jwks_cache_key
          "#{cache_key_prefix}/jwks"
        end

        def discovery_document
          @discovery_document ||= Rails.cache.fetch("#{cache_key_prefix}/discovery", expires_in: 12.hours) do
            JSON.parse(http_get("#{config[:issuer]}/.well-known/openid-configuration"))
          end
        end

        def cache_key_prefix
          config[:cache_key_prefix]
        end

        # Short timeouts because provider discovery runs on the unauthenticated
        # login-page endpoint: Net::HTTP's 60s defaults would let one unreachable
        # identity provider pin a request thread for a minute per call.
        OPEN_TIMEOUT = 2
        READ_TIMEOUT = 5

        def http_get(url)
          uri = URI(url)
          response = http_client(uri).request(Net::HTTP::Get.new(uri))
          raise "#{url} returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

          response.body
        end

        def post_form(url, **form_data)
          uri = URI(url)
          request = Net::HTTP::Post.new(uri)
          request.set_form_data(form_data)

          http_client(uri).request(request)
        end

        def http_client(uri)
          Net::HTTP.new(uri.host, uri.port).tap do |client|
            client.use_ssl = uri.scheme == 'https'
            client.open_timeout = OPEN_TIMEOUT
            client.read_timeout = READ_TIMEOUT
          end
        end
      end
    end
  end
end
