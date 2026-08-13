module Spree
  module Api
    module V3
      module Admin
        # Admin API store context (docs/plans/6.0-store-context-and-first-run-setup.md):
        # a secret key selects its bound store; JWT staff sessions select via
        # the +X-Spree-Store-Id+ header (the admin SDK sends it on every
        # request) and are membership-checked against the store resolved here
        # by AdminAuthentication#require_store_membership!. The request host
        # is never consulted.
        #
        # Included in both Admin API branch anchors (Admin::BaseController and
        # Admin::ResourceController) alongside AdminAuthentication.
        module StoreContext
          extend ActiveSupport::Concern

          STORE_HEADER = 'X-Spree-Store-Id'.freeze

          included do
            # Prepended so Spree::Current.store reflects the requested store
            # before any other callback (locale/currency fallbacks, resource
            # lookups) reads it. The store-presence guard 404s an unknown
            # header ID right after this runs.
            prepend_before_action :set_current_store_context

            # Once-per-process latch for the missing-header notice.
            class_attribute :missing_store_header_warned, default: false, instance_accessor: false
          end

          # Resolution order: the secret key's bound store, then the header,
          # then the default store — deprecated for JWT requests; the header
          # becomes required in 6.1.
          #
          # @return [Spree::Store, nil]
          def current_store
            return @current_store if defined?(@current_store)

            @current_store = resolve_admin_store
          end

          private

          def set_current_store_context
            if secret_api_key && store_id_header && secret_api_key.store&.prefixed_id != store_id_header
              render_error(
                code: ErrorHandler::ERROR_CODES[:access_denied],
                message: Spree.t('api.errors.store_mismatch', default: 'The requested store does not match the store this API key belongs to.'),
                status: :forbidden
              )
              return
            end

            # Assigned even when nil: an unknown store id renders 404 further
            # down the chain, and leaving Spree::Current.store holding the
            # previous request's value on this thread would expose another
            # store to anything reading it before that 404 lands.
            Spree::Current.store = current_store
          end

          def resolve_admin_store
            return secret_api_key.store if secret_api_key

            if store_id_header
              Spree::Store.find_by_prefix_id(store_id_header)
            else
              # Only warn for authenticated staff traffic — credential-less
              # requests (login, refresh, invitation acceptance) are
              # store-agnostic and legitimately send no header.
              warn_missing_store_header if request.authorization.present?
              Spree::Store.default
            end
          end

          def store_id_header
            request.headers[STORE_HEADER].presence
          end

          # A plain once-per-process log line, deliberately NOT
          # Spree::Deprecation: some endpoints structurally cannot carry the
          # header (`/me` runs before any store is selected — it is how the
          # dashboard discovers the user's stores), so a per-request
          # deprecation would be pure noise and would 500 every login
          # bootstrap for apps running deprecations-as-errors.
          def warn_missing_store_header
            return if self.class.missing_store_header_warned
            self.class.missing_store_header_warned = true

            Rails.logger&.info(
              "Admin API v3 requests without an #{STORE_HEADER} header fall back to the default store. " \
              'Multi-store clients should send the header; store-agnostic endpoints (/me, auth) are exempt.'
            )
          end
        end
      end
    end
  end
end
