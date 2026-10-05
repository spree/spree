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
              # Only applications somebody actually authorized — a registered
              # client nobody connected is not a connection. Tokens and their
              # owners are preloaded because the serializer reads each
              # application's scopes, last use and who approved it from them.
              scope = current_store.oauth_applications.
                      where(id: connected_application_ids).
                      includes(live_access_tokens: :resource_owner).
                      order(:name)

              @pagy, applications = pagy(scope, limit: params[:limit] || 25)

              render json: {
                data: Spree.api.admin_oauth_application_serializer.new(applications).serializable_hash,
                meta: {
                  page: @pagy.page, limit: @pagy.limit, count: @pagy.count,
                  pages: @pagy.pages, from: @pagy.from, to: @pagy.to,
                  in: @pagy.in, previous: @pagy.previous, next: @pagy.next
                }
              }
            end

            def destroy
              application = current_store.oauth_applications.find_by_prefix_id!(params[:id])

              authorize! :update, Spree::Store

              application.access_tokens.where(revoked_at: nil).update_all(revoked_at: Time.current)
              application.access_grants.where(revoked_at: nil).update_all(revoked_at: Time.current)

              head :no_content
            end

            private

            # Applications holding a live token, as a subquery so nothing is
            # loaded just to be counted.
            def connected_application_ids
              Spree::OauthAccessToken.not_expired.
                where(resource_owner_type: Spree.admin_user_class.name).
                where(application_id: current_store.oauth_applications.select(:id)).
                select(:application_id)
            end
          end
        end
      end
    end
  end
end
