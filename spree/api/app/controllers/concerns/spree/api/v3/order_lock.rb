module Spree
  module Api
    module V3
      module OrderLock
        extend ActiveSupport::Concern

        private

        def with_order_lock
          order = @order || @parent

          order.with_lock do
            # Persist increment within the transaction so reloads inside yield see the new version
            new_version = order.state_lock_version + 1
            order.update_column(:state_lock_version, new_version)

            yield

            if performed? && response.status >= 400
              # Operation failed — revert the increment
              order.update_column(:state_lock_version, new_version - 1)
            end
          end
        rescue ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout => e
          Rails.error.report(e, context: { order_id: order&.id }, source: 'spree.api.v3')
          render_error(
            code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:order_already_updated],
            message: Spree.t(:order_already_updated),
            status: :conflict
          )
        end
      end
    end
  end
end
