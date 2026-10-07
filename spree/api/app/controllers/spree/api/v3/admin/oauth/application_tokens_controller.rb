module Spree
  module Api
    module V3
      module Admin
        module Oauth
          # A connected client's live credentials.
          #
          # Revoking is deleting these, not deleting the application: the
          # registration stays so the merchant can connect the same client
          # again, while anything still holding a token stops working on its
          # next call.
          class ApplicationTokensController < Spree::Api::V3::Admin::BaseController
            scoped_resource :oauth_applications

            def destroy
              application = current_store.oauth_applications.find_by_prefix_id!(params[:application_id])
              authorize! :update, application

              application.access_tokens.where(revoked_at: nil).update_all(revoked_at: Time.current)
              application.access_grants.where(revoked_at: nil).update_all(revoked_at: Time.current)

              head :no_content
            end
          end
        end
      end
    end
  end
end
