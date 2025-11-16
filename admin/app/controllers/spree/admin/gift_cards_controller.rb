module Spree
  module Admin
    class GiftCardsController < ResourceController
      prepend_before_action :load_user
      prepend_before_action :set_user_id_filter, only: :index
      before_action :add_breadcrumbs
      before_action :load_orders, only: :show

      helper_method :gift_cards_filter_dropdown_value

      private

      def permitted_resource_params
        @permitted_resource_params ||= begin
          params_hash = params.require(:gift_card).permit(permitted_gift_card_attributes)

          if @user.present?
            params_hash.merge(user_id: @user.id)
          else
            params_hash
          end
        end
      end

      def collection_includes
        [:user, :created_by]
      end

      def set_user_id_filter
        return if params[:user_id].blank?

        params[:q] ||= {}
        params[:q][:user_id_eq] = params[:user_id] if params[:user_id].present?
      end

      def location_after_destroy
        if @user.present?
          spree.admin_user_path(@user)
        else
          spree.admin_gift_cards_path
        end
      end

      def location_after_save
        spree.admin_gift_card_path(@object.id)
      end

      def load_user
        @user = Spree.user_class.find_by(id: params[:user_id]) if params[:user_id].present?
      end

      def gift_cards_filter_dropdown_value
        if params.dig(:q, :active).present?
          Spree.t('admin.gift_cards.active')
        elsif params.dig(:q, :expired).present?
          Spree.t(:expired)
        elsif params.dig(:q, :redeemed).present?
          Spree.t('admin.gift_cards.redeemed')
        else
          Spree.t('admin.gift_cards.all_statuses')
        end
      end

      def add_breadcrumbs
        if @user.present?
          @breadcrumb_icon = 'users'
          add_breadcrumb Spree.t(:customers), :admin_users_path
          add_breadcrumb @user.name, spree.admin_user_path(@user)
        else
          @breadcrumb_icon = 'discount'
          add_breadcrumb Spree.t(:promotions), :admin_promotions_path
          add_breadcrumb Spree.t(:gift_cards), :admin_gift_cards_path
        end
      end

      def load_orders
        @orders = @object.orders.includes(:user).order(created_at: :desc)
      end
    end
  end
end
