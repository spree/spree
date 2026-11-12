module Spree
  module Api
    module V3
      module Admin
        # Whether a newer Spree release exists, for the dashboard's update
        # notice. Asks spreecloud.io at most once a day (see Spree::UpdateCheck).
        #
        # The only place the Admin API reveals the running Spree version, so it
        # answers signed-in staff who can manage the store and nobody else. A
        # secret API key gets a 404, like GET /me, and a connected app a 403: an
        # integration credential would otherwise fingerprint the deployment for
        # anyone matching CVEs.
        class UpdatesController < Admin::BaseController
          skip_scope_check!

          before_action :require_staff_session!

          # GET /api/v3/admin/updates
          def show
            authorize! :manage, current_store

            render json: Spree.api.admin_update_status_serializer.new(Spree::UpdateCheck.status).to_h
          end
        end
      end
    end
  end
end
