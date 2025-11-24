module Spree
  module Admin
    module OrdersFiltersHelper
      def params_to_filters(search_params:, vendor: nil, user: nil)
        return if search_params.blank?

        if search_params.is_a?(String)
          search_params = JSON.parse(search_params).deep_symbolize_keys
        end

        search_params.delete(:inventory_units_shipment_id_null) if search_params[:inventory_units_shipment_id_null] == '0'

        if search_params[:number_cont]
          search_params[:number_cont] = search_params[:number_cont].split('-').first
        end

        if search_params[:created_at_gt].present?
          search_params[:created_at_gt] = begin
            # Firstly we parse to date to avoid issues with timezones because frontend sends time in local timezone
            search_params[:created_at_gt].to_date&.in_time_zone(current_timezone)&.beginning_of_day
          rescue StandardError
            ''
          end
        end

        if search_params[:created_at_lt].present?
          search_params[:created_at_lt] = begin
            search_params[:created_at_lt].to_date&.in_time_zone(current_timezone)&.end_of_day
          rescue StandardError
            ''
          end
        end

        if search_params[:completed_at_gt].present?
          search_params[:completed_at_gt] = begin
            search_params[:completed_at_gt].to_date&.in_time_zone(current_timezone)&.beginning_of_day
          rescue StandardError
            ''
          end
        end

        if search_params[:completed_at_lt].present?
          search_params[:completed_at_lt] = begin
            search_params[:completed_at_lt].to_date&.in_time_zone(current_timezone)&.end_of_day
          rescue StandardError
            ''
          end
        end

        search_params[:vendor_orders_vendor_id_eq] = vendor.id if vendor.present?
        search_params[:user_id_eq] = user.id if user.present?

        # Handle refunded and partially_refunded payment state filters
        if search_params[:payment_state_eq] == 'refunded'
          search_params[:refunded] = '1'
          search_params.delete(:payment_state_eq)
        elsif search_params[:payment_state_eq] == 'partially_refunded'
          search_params[:partially_refunded] = '1'
          search_params.delete(:payment_state_eq)
        end

        search_params
      end

      def load_orders
        @search = scope.preload(:user).accessible_by(current_ability, :index).
                  ransack(params_to_filters(search_params: params[:q].clone, vendor: @vendor, user: @user))

        # lazy loading other models here (via includes) may result in an invalid query
        # e.g. SELECT  DISTINCT DISTINCT "spree_orders".id, "spree_orders"."created_at" AS alias_0 FROM "spree_orders"
        # see https://github.com/spree/spree/pull/3919
        @orders = @search.result(distinct: true).page(params[:page]).per(params[:per_page] || Spree::Admin::RuntimeConfig.admin_orders_per_page)
        @collection = @orders
      end

      def load_user
        @user = Spree.user_class.find(params[:user_id]) if params[:user_id].present?
      end
    end
  end
end
