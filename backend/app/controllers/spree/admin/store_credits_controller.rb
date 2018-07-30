module Spree
  module Admin
    class StoreCreditError < StandardError; end

    class StoreCreditsController < Spree::Admin::BaseController
      before_action :load_user
      before_action :load_categories, only: [:new, :edit]
      before_action :load_store_credit, only: [:new, :edit, :update]
      before_action :ensure_unused_store_credit, only: [:update]

      def index
        @store_credits = @user.store_credits.includes(:credit_type, :category).reverse_order
      end

      def create
        @store_credit = @user.store_credits.build(
          permitted_store_credit_params.merge(
            created_by: try_spree_current_user,
            action_originator: try_spree_current_user
          )
        )

        if @store_credit.save
          flash[:success] = flash_message_for(@store_credit, :successfully_created)
          redirect_to admin_user_store_credits_path(@user)
        else
          load_categories
          flash[:error] = Spree.t('store_credit.errors.unable_to_create')
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
          flash[:error] = Spree.t('store_credit.errors.unable_to_update')
          render :edit
        end
      end

      def destroy
        @store_credit = @user.store_credits.find(params[:id])
        ensure_unused_store_credit

        if @store_credit.destroy
          flash[:success] = flash_message_for(@store_credit, :successfully_removed)
          respond_with(@store_credit) do |format|
            format.html { redirect_to admin_user_store_credits_path(@user) }
            format.js { render_js_for_destroy }
          end
        else
          render plain: Spree.t('store_credit.errors.unable_to_delete'), status: :unprocessable_entity
        end
      end

      protected

      def permitted_store_credit_params
        params.require(:store_credit).permit(permitted_store_credit_attributes)
      end

      private

      def load_user
        @user = Spree.user_class.find_by(id: params[:user_id])

        unless @user
          flash[:error] = Spree.t(:user_not_found)
          redirect_to admin_path
        end
      end

      def load_categories
        @credit_categories = Spree::StoreCreditCategory.order(:name)
      end

      def load_store_credit
        @store_credit = Spree::StoreCredit.find_by(id: params[:id]) || Spree::StoreCredit.new
      end

      def ensure_unused_store_credit
        unless @store_credit.amount_used.zero?
          raise StoreCreditError, Spree.t('store_credit.errors.cannot_change_used_store_credit')
        end
      end
    end
  end
end
