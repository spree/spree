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

      def search
        query = params[:q]&.strip

        head :ok and return if query.blank? || query.length < 3

        scope = model_class.accessible_by(current_ability, :index)
        scope = scope.where.not(id: params[:omit_ids].split(',')) if params[:omit_ids].present?
        @users = scope.includes(:bill_address, :ship_address, avatar_attachment: :blob)
                      .multi_search(query)
                      .limit(params[:limit] || 10)

        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace(
                'users_search_results',
                partial: 'spree/admin/users/search_results',
                locals: { users: @users }
              )
            ]
          end
        end
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

      def model_class
        Spree.user_class
      end

      def update_turbo_stream_enabled?
        true
      end

      # Skip setting current store for users as they don't need store assignment
      # and the stores association goes through role_users which requires a role
      def set_current_store
        # no-op for users
      end

      def location_after_save
        spree.admin_user_path(@user)
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

      def permitted_resource_params
        user_params
      end

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

        # Remove spree_role_ids if it only contains empty strings to avoid clearing roles
        role_ids = params[:user][:spree_role_ids]
        if role_ids.present? && role_ids.reject(&:empty?).empty?
          params[:user].delete(:spree_role_ids)
        end
      end

      def load_last_order_data
        @last_order = @user.completed_orders.last
        return unless @last_order.present?

        @last_order_line_items = @last_order.line_items.includes(variant: [:images, { option_values: :option_type }, { product: [:variant_images, { master: :images }, { variants: :images }] }])
      end
    end
  end
end
