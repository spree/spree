module Spree
  module Api
    module V3
      module Oauth
        # The authorization endpoint a client sends the browser to.
        #
        # It renders nothing itself: consent belongs in the dashboard, where
        # the merchant is already signed in and the screen matches the rest of
        # the admin. This hands the request over with its parameters intact,
        # and the dashboard reads them back through the JSON endpoints under
        # /api/v3/admin/oauth.
        #
        # It is a real route rather than a skipped one because RFC 8414
        # requires the metadata document to name an `authorization_endpoint`,
        # and a consumer client refuses a document that advertises the
        # authorization-code flow without one.
        class AuthorizationsController < ActionController::Base
          include Spree::Core::ControllerHelpers::Store

          # The authorization endpoint is reached by a cross-site GET on
          # purpose — a client sends the browser here — so a forgery token
          # cannot be required. It is safe to leave open because the action
          # only redirects: nothing is granted until the merchant submits
          # consent to the Admin API, which does carry its own session.
          protect_from_forgery with: :null_session

          # Carried across to the dashboard. Everything else is dropped, so a
          # crafted link cannot smuggle extra parameters into the consent page.
          FORWARDED_PARAMETERS = %w[
            client_id redirect_uri response_type scope state
            code_challenge code_challenge_method resource
          ].freeze

          def new
            redirect_to consent_url, allow_other_host: true
          end

          private

          def consent_url
            query = params.permit(*FORWARDED_PARAMETERS).to_h.compact_blank.to_query
            base = Spree::Stores::DashboardUrl.call(store: current_store)

            "#{base}/#{current_store.prefixed_id}/oauth/authorize?#{query}"
          end
        end
      end
    end
  end
end
