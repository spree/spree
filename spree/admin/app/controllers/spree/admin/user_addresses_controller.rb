module Spree
  module Admin
    class UserAddressesController < ResourceController
      use_table :addresses

      before_action :redirect_to_full_page, only: :index, unless: :turbo_frame_request?
      skip_after_action :set_return_to, only: :index

      private

      def model_class
        Spree::Address
      end

      # Addresses have no standalone admin page, so rows are not clickable.
      def edit_object_url(_object, _options = {})
        nil
      end

      def parent_data
        {
          model_name: 'spree/user',
          model_class: Spree.user_class,
          find_by: :prefix_id
        }
      end

      def scope
        parent.addresses.accessible_by(current_ability, :index).includes(collection_includes)
      end

      def collection_includes
        %i[country state]
      end

      def redirect_to_full_page
        redirect_to spree.admin_user_path(parent)
      end
    end
  end
end
