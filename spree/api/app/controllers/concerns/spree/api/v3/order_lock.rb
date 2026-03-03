module Spree
  module Api
    module V3
      module OrderLock
        extend ActiveSupport::Concern

        private

        def with_order_lock
          order = @order || @parent

          order.with_lock do
            if params[:state_lock_version].present?
              unless order.state_lock_version == params[:state_lock_version].to_i
                render_error(
                  code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:order_already_updated],
                  message: Spree.t(:order_already_updated),
                  status: :conflict
                )
                return
              end
            end

            order.increment!(:state_lock_version)

            yield
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
