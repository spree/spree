module Spree
  module Api
    module V3
      module Admin
        module Oauth
          # The consent step, as JSON for the dashboard to render.
          #
          # `show` describes what a client is asking for so the dashboard can
          # draw a consent screen in its own design system, with the admin
          # already signed in. `create` grants it and answers with the
          # redirect the browser should follow; `destroy` denies it.
          #
          # Doorkeeper's own controller is not used: it renders HTML and runs
          # its own login, and the dashboard already knows who is signed in.
          class AuthorizationsController < Spree::Api::V3::Admin::BaseController
            # Consent is a person's decision about their own authority, and a
            # secret key has no human behind it, so there is no scope that
            # could make this callable with one — `require_signed_in_admin!`
            # refuses a key outright. Skipped for every principal rather than
            # JWT-only, because leaving the key path in the scope machinery
            # asks this controller for a `scoped_resource` it cannot
            # meaningfully name.
            skip_scope_check!

            before_action :require_signed_in_admin!
            before_action :require_client_of_this_store!
            before_action :load_pre_authorization

            def show
              render json: {
                client_name: client_name,
                scopes: requested_permissions,
                resource: requested_resource,
                redirect_uri: @pre_auth.redirect_uri
              }
            end

            def create
              render json: { redirect_uri: code_request.authorize.redirect_uri }
            end

            def destroy
              render json: { redirect_uri: code_request.deny.redirect_uri }
            end

            private

            # A secret key authenticates but is not a person; `current_actor`
            # returns the key in that case, and a grant must belong to a user.
            def require_signed_in_admin!
              return if current_actor.is_a?(Spree.admin_user_class)

              render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:access_denied],
                message: 'Only a signed-in admin user can authorize an application.',
                status: :forbidden
              )
            end

            # Doorkeeper resolves a client id globally, so without this an
            # admin of one store could consent to another store's registered
            # client. Reading it through the store's own association turns
            # that into a 404, the same defence every other admin lookup
            # uses.
            def require_client_of_this_store!
              return if current_store.oauth_applications.exists?(uid: params[:client_id])

              render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:record_not_found],
                message: 'Unknown application.',
                status: :not_found
              )
            end

            def load_pre_authorization
              @pre_auth = ::Doorkeeper::OAuth::PreAuthorization.new(
                ::Doorkeeper.config,
                pre_authorization_params,
                current_actor
              )

              return if @pre_auth.authorizable?

              render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:resource_invalid],
                message: @pre_auth.error_response.body[:error_description].to_s,
                status: :unprocessable_content
              )
            end

            # Symbol keys: PreAuthorization reads them that way, and a hash of
            # strings silently produces an unauthorizable request.
            def pre_authorization_params
              params.permit(
                :client_id, :redirect_uri, :response_type, :state, :scope,
                :code_challenge, :code_challenge_method, :response_mode
              ).to_h.symbolize_keys.
                # Carried through raw: RFC 8707 allows one value or several,
                # and Doorkeeper's own validator normalizes both shapes.
                merge(resource: params[:resource])
            end

            def requested_resource
              @pre_auth.resource_indicators&.first
            end

            # Every capability the requested scopes imply, so a merchant sees
            # what they are actually granting rather than only the shorthand
            # the client named.
            def requested_permissions
              Spree.permissions.expand_keys(@pre_auth.scopes.to_a).sort
            end

            def client_name
              @pre_auth.client&.application&.name.presence || 'An application'
            end

            # Doorkeeper's own request object builds both redirects. Hand-
            # rolling them means getting out-of-band clients, fragment
            # response mode and the RFC 9207 issuer parameter right by hand,
            # which is exactly the work the gem is here to do.
            def code_request
              @code_request ||= ::Doorkeeper::OAuth::CodeRequest.new(@pre_auth, current_actor)
            end
          end
        end
      end
    end
  end
end
