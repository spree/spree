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
          skip_before_action :authenticate_admin!, only: [:show, :countries, :create]

          rate_limit to: Spree::Api::Config[:rate_limit_login],
                     within: Spree::Api::Config[:rate_limit_window].seconds,
                     store: Rails.cache,
                     only: [:show, :countries, :create],
                     with: -> { render_rate_limited(limit: Spree::Api::Config[:rate_limit_login]) }

          # GET /api/v3/admin/auth/setup
          # Leaks a single boolean that is self-evident on a fresh install —
          # the login page uses it to offer the setup screen.
          def show
            render json: { setup_required: setup_required? }
          end

          # GET /api/v3/admin/auth/setup/countries
          # The setup screen runs before any credential exists, so it cannot
          # use the authenticated countries endpoint. Currency and locales are
          # derived here rather than in the client, so the market the setup
          # builds and the currency the merchant was shown cannot disagree.
          def countries
            return render_setup_unavailable unless setup_required?

            render json: { countries: Spree::Country.all.map { |country| country_payload(country) } }
          end

          # POST /api/v3/admin/auth/setup
          # Body: { setup_token, email, password, password_confirmation?,
          #         first_name?, last_name?, store_name, country_code,
          #         locale?, currency? }
          # Currency defaults to the country's own; an unknown code is refused
          # rather than ignored, since the token is spent in the same request.
          def create
            return render_setup_unavailable unless setup_token_usable?
            return render_missing_country if country.nil?
            return render_unknown_currency if unknown_currency?

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

            refresh_token = Spree::RefreshToken.create_for(user, audience: JWT_AUDIENCE_ADMIN, request_env: request_env_for_token)
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

          # Resolved before the token is spent: setup is one-shot, so a store
          # provisioned for the wrong country would leave no in-band way to
          # correct it.
          def country
            @country ||= Spree::Country.by_iso(params[:country_code]) if params[:country_code].present?
          end

          def render_missing_country
            message = if params[:country_code].present?
                        "Unknown country #{params[:country_code]}"
                      else
                        "Country can't be blank"
                      end

            render_error(
              code: ERROR_CODES[:validation_error],
              message: message,
              status: :unprocessable_content,
              details: { country_code: [message] }
            )
          end

          # Blank means "use the country's own currency"; a code that resolves
          # to nothing is a typo worth refusing before the token is spent.
          def unknown_currency?
            params[:currency].present? && ::Money::Currency.find(params[:currency].to_s.strip).nil?
          end

          def render_unknown_currency
            message = "Unknown currency #{params[:currency]}"

            render_error(
              code: ERROR_CODES[:validation_error],
              message: message,
              status: :unprocessable_content,
              details: { currency: [message] }
            )
          end

          def country_payload(country)
            {
              code: country.iso,
              name: country.name,
              currency: country.default_currency,
              locales: offerable_locales(country)
            }
          end

          # A country's official languages, minus any Spree has no translations
          # for — Switzerland speaks Romansh and Spree does not, so offering it
          # would point a storefront at a language with nothing behind it.
          # English closes the gap for countries whose languages all fall
          # through, and is always offered alongside.
          #
          # Installs without spree_i18n only have English, and filtering
          # against that would leave every country English-only. There the
          # unfiltered list is the better answer: the merchant's own language
          # is still the right default for their storefront, whether or not
          # this install carries a translation bundle for it.
          def offerable_locales(country)
            return country.official_locales if translated_locales.size <= 1

            (country.official_locales & translated_locales).presence || ['en']
          end

          def translated_locales
            @translated_locales ||= Spree.available_locales.map { |locale| locale.to_s.split('-').first }.uniq
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
          #
          # The country-shaped defaults (market, warehouse, delivery zones,
          # pickup) are built here rather than seeded, because the seed ran
          # before anyone had said where the shop sells from.
          def adopt_default_store(user, store)
            store.update!(store_params.merge(setup_token: nil))
            store.add_user(user)

            Spree::Stores::ProvisionDefaults.call(
              store: store,
              country: country,
              locale: params[:locale].presence,
              currency: params[:currency].presence
            )
          end

          # `store_name` is optional: an API client may claim the installation
          # without renaming the seeded store (the dashboard's form requires
          # it, but the endpoint is the documented surface).
          def store_params
            params[:store_name].present? ? { name: params[:store_name] } : {}
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
