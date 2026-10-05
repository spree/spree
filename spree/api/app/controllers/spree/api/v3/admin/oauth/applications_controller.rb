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
                             where(id: live_tokens_by_application.keys).
                             order(:name)

              render json: { data: applications.map { |application| serialize(application) } }
            end

            def destroy
              application = current_store.oauth_applications.find_by_prefix_id!(params[:id])

              authorize! :update, Spree::Store

              application.access_tokens.where(revoked_at: nil).update_all(revoked_at: Time.current)
              application.access_grants.where(revoked_at: nil).update_all(revoked_at: Time.current)

              head :no_content
            end

            private

            # Scopes come from the live tokens, not the registration: a
            # client is registered once and granted per consent, so the
            # registration's own `scopes` column stays empty and what the
            # merchant actually approved lives on the tokens.
            def serialize(application)
              tokens = live_tokens_by_application[application.id].to_a

              {
                id: application.prefixed_id,
                name: application.name,
                scopes: tokens.flat_map { |token| token.scopes.to_a }.uniq.sort,
                last_used_at: tokens.map(&:created_at).max,
                created_at: application.created_at
              }
            end

            # The live tokens for this store's applications, which answer both
            # which clients are connected and what each was granted. Scoped to
            # the store so a multi-store installation does not load every
            # token it holds to render one page.
            def live_tokens_by_application
              @live_tokens_by_application ||=
                Spree::OauthAccessToken.
                where(revoked_at: nil, resource_owner_type: Spree.admin_user_class.name).
                where(application_id: current_store.oauth_applications.select(:id)).
                group_by(&:application_id)
            end
          end
        end
      end
    end
  end
end
