module Spree
  module Api
    module V3
      module Admin
        class DashboardController < Admin::BaseController
          scoped_resource :dashboard

          # GET /api/v3/admin/dashboard/analytics
          def analytics
            date_from = (params[:date_from] || 30.days.ago).to_time.beginning_of_day
            date_to = (params[:date_to] || Time.current).to_time.end_of_day
            currency = params[:currency] || current_store.default_currency

            serializer = DashboardAnalyticsSerializer.new(
              store: current_store,
              currency: currency,
              time_range: date_from..date_to,
              params: serializer_params
            )

            render json: serializer.to_h
          end

          private

          def action_kind
            'read'
          end

          def serializer_params
            {
              store: current_store,
              locale: current_locale,
              currency: current_currency,
              user: current_user,
              includes: [],
              expand: []
            }
          end
        end
      end
    end
  end
end
