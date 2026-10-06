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

            # Raised when Doorkeeper refuses the bounded pre-authorization.
            # An exception rather than a render, because the refusal happens
            # inside a helper the action reads a value from — returning there
            # would hand the action a rendered body to call methods on.
            class InvalidAuthorization < StandardError; end

            rescue_from InvalidAuthorization do |error|
              render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:resource_invalid],
                message: error.message,
                status: :unprocessable_content
              )
            end

            before_action :require_signed_in_admin!
            before_action :require_client_of_this_store!
            before_action :load_pre_authorization
            before_action :require_something_to_grant!, only: :create

            def show
              render json: {
                client_name: client_name,
                scopes: requested_permissions,
                # What the merchant may hand over, which is the intersection
                # of what the client asked for and what they themselves hold.
                # A grant can only ever narrow their own authority, so
                # offering more than they have would be offering a refusal.
                grantable_scopes: grantable_scopes,
                resource: requested_resource,
                redirect_uri: @pre_auth.redirect_uri
              }
            end

            # The merchant may approve less than the client asked for, and
            # never more than they themselves hold.
            #
            # The ceiling is applied here rather than trusted from the
            # request. Doorkeeper validates a requested scope against the
            # catalog, not against the person, so a crafted POST naming
            # `write_settings` would otherwise be recorded verbatim on a
            # staffer who holds only `read_products` — and a grant is a
            # standing ceiling, so it would widen on its own the day that
            # person is promoted.
            def create
              render json: { redirect_uri: granted_code_request.authorize.redirect_uri }
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

            # What this person can actually grant: the requested scopes minus
            # anything their own role does not carry.
            #
            # @return [Array<String>]
            # Every individual permission the merchant could hand over, which
            # is what the consent screen draws a row for.
            def grantable_scopes
              held = current_ability.try(:permission_keys)&.map(&:to_s) || []
              requested = Spree.permissions.expand_keys(@pre_auth.scopes.to_a)

              (requested & held).sort
            end

            # What the grant records, given what the merchant left ticked.
            #
            # An untouched "everything" stays an alias rather than becoming a
            # list. Enumerating would freeze it: ship a feature with new
            # permissions and the grant does not name them, so an agent the
            # merchant gave full access silently cannot use the new tools and
            # nothing says why. A narrowed selection is a deliberate list and
            # stays one.
            def recorded_scopes
              granted = selected_scopes
              return granted unless granted.sort == grantable_scopes.sort
              return granted unless records_as_alias?

              requested = @pre_auth.scopes.to_a
              return ['write_all'] if requested.include?('write_all')

              ['read_all']
            end

            # An alias is only safe for someone who holds everything it
            # stands for.
            #
            # It is resolved against the token owner's ability at each
            # request, so recording it for a limited staffer would widen the
            # grant the day they are promoted — the standing-ceiling problem
            # the intersection exists to prevent. A partial holder gets the
            # list their authority actually covers.
            def records_as_alias?
              requested = @pre_auth.scopes.to_a
              return false unless requested.intersect?(Spree::Api::Oauth::ALIAS_SCOPES)

              held = current_ability.try(:permission_keys)&.map(&:to_s) || []
              catalog = Spree.permissions.grantable_keys(
                Spree::PermissionConfiguration::STAFF_AUDIENCE
              ).map(&:to_s)

              (catalog - held).empty?
            end

            # What the merchant left ticked, bounded by what they may give.
            def selected_scopes
              submitted = Spree.permissions.expand_keys(params[:scope].to_s.split)
              return grantable_scopes if submitted.empty?

              (submitted & grantable_scopes).sort
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

            # The same thing, over a pre-authorization whose scope has been
            # cut to what this person can actually hand over. Rebuilt rather
            # than mutated, because the scope is read in several places on
            # the way to the grant.
            # A grant that carries nothing is not a grant. It happens when the
            # merchant clears every box, or when the client asks only for
            # permissions this person does not hold, and it would otherwise
            # mint a token that authorizes nothing while the client reports a
            # successful connection and the merchant sees the application
            # listed as connected.
            def require_something_to_grant!
              return if selected_scopes.any?

              render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:resource_invalid],
                message: 'Select at least one permission to grant.',
                status: :unprocessable_content
              )
            end

            def granted_code_request
              bounded = ::Doorkeeper::OAuth::PreAuthorization.new(
                ::Doorkeeper.config,
                pre_authorization_params.merge(scope: recorded_scopes.join(' ')),
                current_actor
              )

              # Validation is what resolves `client`, and the grant is written
              # from `pre_auth.client.id` — an unvalidated pre-authorization
              # carries a nil client and fails deep inside the gem.
              raise InvalidAuthorization, bounded.error_response.body[:error_description].to_s unless
                bounded.authorizable?

              ::Doorkeeper::OAuth::CodeRequest.new(bounded, current_actor)
            end
          end
        end
      end
    end
  end
end
