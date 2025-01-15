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
        base_scope = scope.preload(:user).accessible_by(current_ability, :index)

        if params.dig(:q, :multisearch).present?
          shared_context = Ransack::Context.for(Spree::Order)

          search_by_number = Spree::Order.ransack(
            { number_i_cont: params.dig(:q, :multisearch) }, context: shared_context
          )

          search_by_email = Spree::Order.ransack(
            { email_eq: params.dig(:q, :multisearch) }, context: shared_context
          )

          search_by_firstname = Spree::Order.ransack(
            { bill_address_firstname_i_cont_any: params.dig(:q, :multisearch) }, context: shared_context
          )

          search_by_lastname = Spree::Order.ransack(
            { bill_address_lastname_eq: params.dig(:q, :multisearch) }, context: shared_context
          )

          shared_conditions = [search_by_number, search_by_email, search_by_firstname, search_by_lastname].map do |search|
            Ransack::Visitor.new.accept(search.base)
          end

          @multisearch_orders = base_scope.joins(shared_context.join_sources).where(shared_conditions.reduce(&:or)).distinct
        end

        @search = base_scope.ransack(params_to_filters(search_params: params[:q].clone, vendor: @vendor, user: @user))

        # lazy loading other models here (via includes) may result in an invalid query
        # e.g. SELECT  DISTINCT DISTINCT "spree_orders".id, "spree_orders"."created_at" AS alias_0 FROM "spree_orders"
        # see https://github.com/spree/spree/pull/3919
        @orders = @search.result(distinct: true)
        @orders = @orders.merge(@multisearch_orders) if @multisearch_orders.present?
        @orders = @orders.page(params[:page]).per(params[:per_page])
      end

      def load_user
        @user = Spree.user_class.find(params[:user_id]) if params[:user_id].present?
      end

      def assign_filter_badges
        @filter_badges ||= begin
          badges = {}

          if params.dig(:q, :bill_address_firstname_i_cont_any).present?
            badges[:bill_address_firstname_i_cont_any] =
              { label: Spree.t(:first_name), value: params[:q][:bill_address_firstname_i_cont_any] }
          end

          if params.dig(:q, :bill_address_lastname_eq).present?
            badges[:bill_address_lastname_eq] =
              { label: Spree.t(:last_name), value: params[:q][:bill_address_lastname_eq] }
          end

          badges[:email_eq] = { label: Spree.t(:email), value: params[:q][:email_eq] } if params.dig(:q, :email_eq).present?

          if params.dig(:q, :line_items_variant_sku_eq).present?
            badges[:line_items_variant_sku_eq] = { label: Spree.t(:sku), value: params[:q][:line_items_variant_sku_eq] }
          end

          if params.dig(:q, :promotions_id_in).present?
            badges[:promotions_id_in] = {
              label: Spree.t(:promotion),
              value: Spree::Promotion.where(id: params[:q][:promotions_id_in]).pluck(:name).join(', ')
            }
          end

          if params.dig(:q, :vendor_orders_vendor_id_eq).present?
            badges[:vendor_orders_vendor_id_eq] = {
              label: Spree.t(:vendor),
              value: Spree::Vendor.where(id: params[:q][:vendor_orders_vendor_id_eq]).pluck(:name).join(', ')
            }
          end

          badges
        end
      end
    end
  end
end
