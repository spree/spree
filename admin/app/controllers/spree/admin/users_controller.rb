module Spree
  module Admin
    class UsersController < ResourceController
      helper UsersHelper

      include Spree::Admin::BulkOperationsConcern

      rescue_from Spree::Core::DestroyWithOrdersError, with: :user_destroy_with_orders_error

      before_action :load_last_order_data, only: :show
      before_action :remove_empty_params, only: :update

      add_breadcrumb_icon 'users'
      add_breadcrumb Spree.t(:customers), :admin_users_path

      def select_options
        search_params = params[:q].is_a?(String) ? { email_cont: params[:q] } : params[:q]
        users = model_class.ransack(search_params).result.order(:email).limit(50)

        render json: users.pluck(:id, :email).map { |id, email| { id: id, name: email } }
      end

      def show
        add_breadcrumb @user.name, spree.admin_user_path(@user)
      end

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
          respond_to do |format|
            format.turbo_stream do
              flash.now[:success] = flash_message_for(@user, :successfully_updated)
            end
            format.html do
              flash[:success] = flash_message_for(@user, :successfully_updated)
              redirect_to spree.admin_user_path(@user)
            end
          end
        else
          respond_to do |format|
            format.turbo_stream do
              flash.now[:error] = @user.errors.full_messages.join(', ')
              render :update, status: :unprocessable_entity
            end
            format.html do
              render :edit, status: :unprocessable_entity
            end
          end
        end
      end

      def model_class
        Spree.user_class
      end

      protected

      def collection_includes
        {
          addresses: [:country, :state],
          ship_address: [:country, :state],
          bill_address: [:country, :state],
          avatar_attachment: :blob
        }
      end

      def find_resource
        model_class.accessible_by(current_ability, :show).find(params[:id])
      end

      def collection_url
        spree.admin_users_path
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
        return unless @last_order.present?

        @last_order_line_items = @last_order.line_items.includes(variant: [:images, { option_values: :option_type }, { product: [:variant_images, { master: :images }, { variants: :images }] }])
      end
    end
  end
end
