module Spree
  module Admin
    class UserAddressesController < ResourceController
      use_table :addresses

      before_action :redirect_to_full_page, only: :index, unless: :turbo_frame_request?

      private

      def model_class
        Spree::Address
      end

      def edit_object_url(_object, _options = {})
        nil
      end

      def parent
        @parent ||= Spree.user_class.accessible_by(current_ability, :show).find_by_prefix_id!(params[:user_id])
        @user = @parent
      end

      def scope
        parent.addresses.accessible_by(current_ability, :index).includes(collection_includes)
      end

      def collection_includes
        %i[country state]
      end

      def collection_url(_options = {})
        spree.admin_users_path
      end

      def redirect_to_full_page
        redirect_to spree.admin_user_path(parent)
      end
    end
  end
end
