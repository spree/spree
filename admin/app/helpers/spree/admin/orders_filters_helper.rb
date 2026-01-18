module Spree
  module Admin
    module OrdersFiltersHelper
      def search_params
        super
        return params[:q] if params[:q].blank?

        if params[:q][:completed_at_gt].present?
          params[:q][:completed_at_gt] = begin
            params[:q][:completed_at_gt].to_date&.in_time_zone(current_timezone)&.beginning_of_day
          rescue StandardError
            ''
          end
        end

        if params[:q][:completed_at_lt].present?
          params[:q][:completed_at_lt] = begin
            params[:q][:completed_at_lt].to_date&.in_time_zone(current_timezone)&.end_of_day
          rescue StandardError
            ''
          end
        end

        load_user
        params[:q][:user_id_eq] = @user.id if @user.present?

        # Handle refunded and partially_refunded payment state filters
        if params[:q][:payment_state_eq] == 'refunded'
          params[:q][:refunded] = '1'
          params[:q].delete(:payment_state_eq)
        elsif params[:q][:payment_state_eq] == 'partially_refunded'
          params[:q][:partially_refunded] = '1'
          params[:q].delete(:payment_state_eq)
        end

        params[:q]
      end

      def load_user
        @user = Spree.user_class.find(params[:user_id]) if params[:user_id].present?
      end
    end
  end
end
