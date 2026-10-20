module Spree
  module Api
    module V3
      module Admin
        # Whether a newer Spree release exists, for the dashboard's update
        # notice. Asks spreecloud.io at most once a day (see Spree::UpdateCheck).
        #
        # The only place the Admin API reveals the running Spree version, so it
        # answers signed-in staff who can manage the store and nobody else. A
        # secret API key gets a 404, like GET /me: an integration key would
        # otherwise fingerprint the deployment for anyone matching CVEs.
        class UpdatesController < Admin::BaseController
          skip_scope_check!

          before_action :require_current_user!

          # GET /api/v3/admin/updates
          def show
            authorize! :manage, current_store

            render json: Spree.api.admin_update_status_serializer.new(Spree::UpdateCheck.status).to_h
          end

          private

          def require_current_user!
            return if current_user

            render_error(
              code: ERROR_CODES[:record_not_found],
              message: I18n.t('spree.me_no_current_user'),
              status: :not_found
            )
          end
        end
      end
    end
  end
end
