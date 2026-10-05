module Spree
  module Api
    module V3
      module Admin
        module Oauth
          # Connected applications, so a merchant can see which agents and
          # apps hold access to the store and take it away.
          #
          # Revoking is the off switch and has to be immediate: it revokes
          # every live token and grant rather than deleting the registration,
          # so a client that still holds a token stops working on its next
          # call.
          class ApplicationsController < Spree::Api::V3::Admin::BaseController
            # Listing and revoking connected apps is store configuration.
            scoped_resource :settings

            def index
              applications = current_store.oauth_applications.
                             where(id: connected_application_ids).
                             order(:name)

              render json: applications.map { |application| serialize(application) }
            end

            def destroy
              application = current_store.oauth_applications.find_by_prefix_id!(params[:id])

              authorize! :update, Spree::Store

              application.access_tokens.where(revoked_at: nil).update_all(revoked_at: Time.current)
              application.access_grants.where(revoked_at: nil).update_all(revoked_at: Time.current)

              head :no_content
            end

            private

            # Only applications somebody actually authorized — a registered
            # client nobody connected is not a connection.
            def connected_application_ids
              Spree::OauthAccessToken.where(revoked_at: nil).
                where(resource_owner_type: Spree.admin_user_class.name).
                select(:application_id)
            end

            def serialize(application)
              {
                id: application.prefixed_id,
                name: application.name,
                scopes: application.scopes.to_a.sort,
                last_used_at: application.last_used_at,
                created_at: application.created_at
              }
            end
          end
        end
      end
    end
  end
end
