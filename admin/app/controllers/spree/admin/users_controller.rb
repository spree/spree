module Spree
  module Admin
    class UsersController < ResourceController
      helper UsersHelper

      include Spree::Admin::BulkOperationsConcern

      rescue_from Spree::Core::DestroyWithOrdersError, with: :user_destroy_with_orders_error

      before_action :load_last_order_data, only: :show
      before_action :remove_empty_params, only: :update

      def show; end

      def create
        @user = Spree.user_class.new(user_params)
        @user.password ||= SecureRandom.hex(16) # we need to set a password to pass validation
        @user.password_confirmation ||= @user.password

        if @user.save
          flash[:success] = flash_message_for(@user, :successfully_created)
          redirect_to spree.admin_user_path(@user)
        else
          render :new, status: :unprocessable_entity
        end
      end

      def update
        if @user.update(user_params)
          flash[:success] = Spree.t(:account_updated)
          redirect_to spree.admin_user_path(@user)
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def model_class
        Spree.user_class
      end

      def bulk_modal
        @title = Spree.t("admin.bulk_ops.users.title.#{params[:kind]}")
        @body = Spree.t("admin.bulk_ops.users.body.#{params[:kind]}")
      end

      protected

      def collection
        return @collection if @collection.present?

        params[:q] ||= {}
        params[:q][:s] ||= 'created_at desc'
        params[:q][:created_at_not_null] ||= 1

        @collection = super
        @search = @collection.ransack(params[:q])
        @collection = @search.result(distinct: true).
                      includes(
                        addresses: [:country, :state],
                        ship_address: [:country, :state],
                        bill_address: [:country, :state],
                        avatar_attachment: :blob
                      ).
                      page(params[:page]).per(params[:per_page])
      end

      private

      def user_params
        params.require(:user).permit(permitted_user_attributes | [spree_role_ids: []])
      end

      # handling raise from Spree::Admin::ResourceController#destroy
      def user_destroy_with_orders_error
        invoke_callbacks(:destroy, :fails)
        render status: :forbidden, plain: Spree.t(:error_user_destroy_with_orders)
      end

      def remove_empty_params
        return if params[:user].blank?

        params[:user][:tag_list] = params.dig(:user, :tag_list).present? ? params.dig(:user, :tag_list).reject(&:empty?) : []
      end

      def load_last_order_data
        @last_order = @user.completed_orders.last
        @last_order_line_items = @last_order.line_items.includes(variant: :product) if @last_order.present?
      end
    end
  end
end
