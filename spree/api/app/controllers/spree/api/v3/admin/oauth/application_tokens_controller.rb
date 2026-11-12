module Spree
  module Api
    module V3
      module Admin
        module Oauth
          # A connected client's live tokens — one per person who connected it.
          #
          # A store registers a client once and every staff member connects to
          # that same registration, so the application row says that Claude is
          # connected while these say by whom. Revoking one cuts off that
          # person and leaves their colleagues working; deleting the
          # application removes the registration itself.
          class ApplicationTokensController < Spree::Api::V3::Admin::ResourceController
            scoped_resource :oauth_applications

            # Revoking rather than deleting: the row records who held access,
            # and Doorkeeper treats a revoked token as gone on the next call.
            def destroy
              @resource.revoke
              head :no_content
            end

            protected

            def model_class
              Spree::OauthAccessToken
            end

            def serializer_class
              Spree.api.admin_oauth_access_token_serializer
            end

            # Live means unrevoked, not unexpired: an access token lasts
            # hours while the refresh token beside it lasts far longer, so a
            # person whose access has lapsed can mint another at will.
            # Hiding them would hide a connection from the screen that exists
            # to cut it off.
            def scope
              application.live_access_tokens.order(created_at: :desc)
            end

            def collection_includes
              [:resource_owner]
            end

            # Nested under its application, so tenancy comes from the parent
            # rather than from the token's own store column.
            def application
              @application ||= current_store.oauth_applications.find_by_prefix_id!(params[:application_id])
            end
          end
        end
      end
    end
  end
end
