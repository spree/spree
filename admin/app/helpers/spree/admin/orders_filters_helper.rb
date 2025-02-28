module Spree
  module Admin
    module OrdersFiltersHelper
      def params_to_filters(search_params:, vendor: nil, user: nil)
        if search_params.is_a?(String)
          search_params = JSON.parse(search_params).deep_symbolize_keys
        end

        search_params.delete(:inventory_units_shipment_id_null) if search_params[:inventory_units_shipment_id_null] == '0'

        if search_params[:number_cont]
          search_params[:number_cont] = search_params[:number_cont].split('-').first
        end

        if search_params[:created_at_gt].present?
          search_params[:created_at_gt] = begin
                                            Time.zone.parse(search_params[:created_at_gt]).beginning_of_day
                                          rescue StandardError
                                            ''
                                          end
        end

        if search_params[:created_at_lt].present?
          search_params[:created_at_lt] = begin
                                            Time.zone.parse(search_params[:created_at_lt]).end_of_day
                                          rescue StandardError
                                            ''
                                          end
        end

        if search_params[:completed_at_gt].present?
          search_params[:completed_at_gt] = begin
                                            Time.zone.parse(search_params[:completed_at_gt]).beginning_of_day
                                          rescue StandardError
                                            ''
                                          end
        end

        if search_params[:completed_at_lt].present?
          search_params[:completed_at_lt] = begin
                                            Time.zone.parse(search_params[:completed_at_lt]).end_of_day
                                          rescue StandardError
                                            ''
                                          end
        end

        search_params[:vendor_orders_vendor_id_eq] = vendor.id if vendor.present?
        search_params[:user_id_eq] = user.id if user.present?

        search_params
      end

      def load_orders
        @search = scope.preload(:user).accessible_by(current_ability, :index).
                  ransack(params_to_filters(search_params: params[:q].clone, vendor: @vendor, user: @user))

        # lazy loading other models here (via includes) may result in an invalid query
        # e.g. SELECT  DISTINCT DISTINCT "spree_orders".id, "spree_orders"."created_at" AS alias_0 FROM "spree_orders"
        # see https://github.com/spree/spree/pull/3919
        @orders = @search.result(distinct: true).page(params[:page]).per(params[:per_page])
      end

      def load_user
        @user = Spree.user_class.find(params[:user_id]) if params[:user_id].present?
      end
    end
  end
end
