module Spree
  module Api
    module V3
      module Admin
        # Refuses every maintenance task endpoint when the installation has
        # turned them off (Spree::Config.maintenance_tasks_dashboard_enabled).
        # The ability already withholds them from signed-in staff; this also
        # covers secret API keys, which are authorized by scope instead.
        #
        # Runs ahead of every other callback, so the caller learns the feature
        # is off rather than a lookup or permission failure that no grant could
        # fix — whether the caller is signed in does not change that answer.
        module MaintenanceTasksSwitch
          extend ActiveSupport::Concern

          included do
            before_action :ensure_maintenance_tasks_enabled, prepend: true
          end

          private

          def ensure_maintenance_tasks_enabled
            return if Spree::Config.maintenance_tasks_dashboard_enabled

            render_error(
              code: ErrorHandler::ERROR_CODES[:access_denied],
              message: I18n.t('spree.maintenance_tasks_turned_off'),
              status: :forbidden
            )
          end
        end
      end
    end
  end
end
