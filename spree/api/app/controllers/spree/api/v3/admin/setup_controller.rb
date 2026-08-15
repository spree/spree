module Spree
  module Api
    module V3
      module Admin
        # First-run setup (docs/plans/6.0-store-context-and-first-run-setup.md):
        # a one-time, token-guarded flow that creates the first admin user and
        # adopts the seeded store. Mounted under `/api/v3/admin/auth/...` so
        # the issued refresh-token cookie's path matches `/auth/refresh` —
        # same shape as invitation acceptance. Dead permanently once any
        # admin user exists.
        class SetupController < BaseController
          include Spree::Api::V3::Admin::AuthCookies

          skip_scope_check!
          skip_before_action :authenticate_admin!, only: [:show, :create]

          rate_limit to: Spree::Api::Config[:rate_limit_login],
                     within: Spree::Api::Config[:rate_limit_window].seconds,
                     store: Rails.cache,
                     only: [:show, :create],
                     with: -> { render_rate_limited(limit: Spree::Api::Config[:rate_limit_login]) }

          # GET /api/v3/admin/auth/setup
          # Leaks a single boolean that is self-evident on a fresh install —
          # the login page uses it to offer the setup screen.
          def show
            render json: { setup_required: setup_required? }
          end

          # POST /api/v3/admin/auth/setup
          # Body: { setup_token, email, password, password_confirmation?,
          #         first_name?, last_name?, store_name, currency?, country_iso? }
          def create
            return render_setup_unavailable unless setup_token_usable?
            return render_unknown_country if unknown_country_iso?

            user = nil
            store = Spree::Store.default

            # The token is one-time, so the guard above must not be a bare
            # check-then-act: two requests carrying the same token can both
            # pass it and each create an admin. Re-checking under a row lock
            # on the store serializes them — the loser sees a spent token.
            store.with_lock do
              return render_setup_unavailable unless setup_token_usable?(store.reload)

              user = Spree.admin_user_class.create!(admin_user_params)
              adopt_default_store(user, store)
            end

            refresh_token = Spree::RefreshToken.create_for(user, request_env: request_env_for_token)
            set_refresh_cookie(refresh_token)
            render json: auth_response(user)
          rescue ActiveRecord::RecordInvalid => e
            render_validation_error(e.record.errors)
          end

          private

          def setup_required?
            Spree.admin_user_class.present? && Spree.admin_user_class.count.zero?
          end

          # The token lives on the default store (has_secure_token) and only
          # authorizes setup while no admin user exists.
          def setup_token_usable?(store = Spree::Store.default)
            return false unless setup_required?

            provided = params[:setup_token].to_s
            stored = store&.setup_token

            provided.present? && stored.present? &&
              ActiveSupport::SecurityUtils.secure_compare(stored, provided)
          end

          # Checked before the token is spent: setup is one-shot, so applying a
          # store with the wrong country — or silently ignoring the request —
          # would leave no in-band way to correct it.
          def unknown_country_iso?
            params[:country_iso].present? && Spree::Country.by_iso(params[:country_iso]).nil?
          end

          def render_unknown_country
            render_error(
              code: ERROR_CODES[:resource_invalid],
              message: "Unknown country #{params[:country_iso]}",
              status: :unprocessable_content
            )
          end

          # Token mismatch, spent token, and already-set-up all render the
          # same 404 so the endpoint leaks nothing about which it was.
          def render_setup_unavailable
            render_error(
              code: ERROR_CODES[:record_not_found],
              message: 'Setup is not available',
              status: :not_found
            )
          end

          def admin_user_params
            params.permit(:email, :password, :password_confirmation, :first_name, :last_name)
          end

          # The seed already created the default store (every downstream seed
          # depends on it existing) — setup claims and renames it rather than
          # creating a second one, and spends the token.
          def adopt_default_store(user, store)
            store.update!(store_params.merge(setup_token: nil))
            store.add_user(user)
          end

          # `store_name` is optional: an API client may claim the installation
          # without renaming the seeded store (the dashboard's form requires
          # it, but the endpoint is the documented surface). `currency` and
          # `country_iso` are applied only when they resolve to something real
          # — the token is spent in the same request, so persisting a typo
          # here would be unrecoverable in-band.
          def store_params
            @store_params ||= begin
              permitted = {}
              permitted[:name] = params[:store_name] if params[:store_name].present?

              if params[:currency].present?
                currency = ::Money::Currency.find(params[:currency].to_s.strip)
                permitted[:default_currency] = currency.iso_code if currency
              end

              if params[:country_iso].present?
                country = Spree::Country.by_iso(params[:country_iso])
                permitted[:default_country_iso_code] = country.iso if country
              end

              permitted
            end
          end

          def auth_response(user)
            {
              token: generate_jwt(user, audience: JWT_AUDIENCE_ADMIN),
              user: Spree.api.admin_admin_user_serializer.new(user, params: serializer_params).to_h
            }
          end

          def serializer_params
            {
              store: Spree::Store.default,
              locale: current_locale,
              currency: current_currency,
              user: nil,
              includes: []
            }
          end

          def request_env_for_token
            {
              ip_address: request.remote_ip,
              user_agent: request.user_agent&.truncate(255)
            }
          end

          def jwt_expiration
            Spree::Api::Config[:admin_jwt_expiration]
          end
        end
      end
    end
  end
end
