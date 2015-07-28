module Spree
  module Admin
    class StoreCreditError < StandardError; end

    class StoreCreditsController < Spree::Admin::BaseController

      before_filter :load_user
      before_filter :load_categories, only: [:new, :edit]
      before_filter :load_store_credit, only: [:new, :edit, :update]
      before_filter :ensure_unused_store_credit, only: [:update]

      def index
        @store_credits = @user.store_credits.reverse_order
      end

      def create
        @store_credit = @user.store_credits.build(
          permitted_store_credit_params.merge({
            created_by: try_spree_current_user,
            action_originator: try_spree_current_user,
          })
        )

        if @store_credit.save
          flash[:success] = flash_message_for(@store_credit, :successfully_created)
          redirect_to admin_user_store_credits_path(@user)
        else
          load_categories
          flash[:error] = Spree.t("store_credit.errors.unable_to_create")
          render :new
        end
      end

      def update
        @store_credit.assign_attributes(permitted_store_credit_params)
        @store_credit.created_by = try_spree_current_user

        if @store_credit.save
          flash[:success] = flash_message_for(@store_credit, :successfully_updated)
          redirect_to admin_user_store_credits_path(@user)
        else
          load_categories
          flash[:error] = Spree.t("store_credit.errors.unable_to_update")
          render :edit
        end
      end

      def destroy
        @store_credit = @user.store_credits.find(params[:id])
        ensure_unused_store_credit

        if @store_credit.destroy
          respond_with(@store_credit) do |format|
            format.html { redirect_to admin_user_store_credits_path(@user) }
            format.js  { render_js_for_destroy }
          end
        else
          render text: Spree.t("store_credit.errors.unable_to_delete"), status: :unprocessable_entity
        end
      end

      protected

      def permitted_store_credit_params
        params.require(:store_credit).permit(permitted_attributes).merge(currency: Spree::Config[:currency])
      end

      private

      def load_user
        @user = Spree.user_class.find(params[:user_id])
      end

      def load_categories
        @credit_categories = Spree::StoreCreditCategory.all.order(:name)
      end

      def load_store_credit
        @store_credit = Spree::StoreCredit.find_by_id(params[:id]) || Spree::StoreCredit.new
      end

      def permitted_attributes
        [:amount, :category_id, :memo]
      end

      def ensure_unused_store_credit
        unless @store_credit.amount_used.zero?
          raise StoreCreditError.new(Spree.t('store_credit.errors.cannot_change_used_store_credit'))
        end
      end

    end
  end
end
