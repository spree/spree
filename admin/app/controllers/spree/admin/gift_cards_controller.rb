module Spree
  module Admin
    class GiftCardsController < ResourceController
      before_action :load_user, only: [:new, :create, :edit, :update, :destroy]
      before_action :add_breadcrumbs

      helper_method :gift_cards_filter_dropdown_value

      private

      def permitted_resource_params
        if @user.present?
          super.merge(user_id: @user.id)
        else
          super
        end
      end

      def collection
        return @collection if @collection.present?

        @collection = super

        params[:q] ||= {}
        params[:q][:s] ||= 'created_at desc'
        params[:q][:user_id_eq] = params[:user_id] if params[:user_id].present?

        @search = @collection

        @search = @search.expired if params[:q][:status_eq] == 'expired'
        @search = @search.active if params[:q][:status_eq] == 'active'
        @search = @search.redeemed if params[:q][:status_eq] == 'redeemed'

        @search = @search.where(code: params[:q][:code_eq].strip) if params[:q][:code_eq].present?

        @search = @search.ransack(params[:q])

        @collection = @search.result

        @collection = @collection.page(params[:page]).per(params[:per_page]) if params[:format] != 'csv'

        @collection
      end

      def location_after_destroy
        if @user.present?
          spree.admin_user_path(@user)
        else
          spree.admin_gift_cards_path
        end
      end

      def location_after_save
        if @user.present?
          spree.edit_admin_user_gift_card_path(@object, user_id: @user.id)
        else
          spree.edit_admin_gift_card_path(@object.id)
        end
      end

      def load_user
        @user = Spree.user_class.find_by(id: params[:user_id])
      end

      def gift_cards_filter_dropdown_value
        case params[:q][:status_eq]
        when 'active'
          Spree.t('admin.gift_cards.active')
        when 'expired'
          Spree.t('admin.gift_cards.expired')
        when 'redeemed'
          Spree.t('admin.gift_cards.redeemed')
        else
          Spree.t('admin.gift_cards.all')
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
    end
  end
end
