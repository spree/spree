module Spree
  module Admin
    class CustomerGroupUsersController < ResourceController
      include BulkOperationsConcern

      prepend_before_action :set_customer_group

      def bulk_new
        # Render the drawer form for adding users
      end

      def bulk_create
        @customer_group.add_customers(bulk_collection.pluck(:id))

        @collection = collection

        flash.now[:success] = Spree.t(:customers_added_to_group, count: bulk_collection.size)
      end

      def create
        user_ids = params[:user_ids].to_a.reject(&:blank?)

        if user_ids.empty?
          flash[:error] = Spree.t(:no_users_selected)
          redirect_to spree.admin_customer_group_path(@customer_group)
          return
        end

        added_count = @customer_group.add_customers(user_ids)

        flash[:success] = Spree.t(:customers_added_to_group, count: added_count)
        redirect_to spree.admin_customer_group_path(@customer_group)
      end

      def destroy
        deleted_count = @customer_group.remove_customers([params[:id]])

        if deleted_count > 0
          flash[:success] = Spree.t(:customer_removed_from_group)
        else
          flash[:error] = Spree.t(:customer_could_not_be_removed_from_group)
        end

        redirect_to spree.admin_customer_group_path(@customer_group)
      end

      def bulk_destroy
        user_ids = Array(params[:ids]).reject(&:blank?)

        if user_ids.empty?
          flash.now[:error] = Spree.t(:no_users_selected)
        else
          deleted_count = @customer_group.remove_customers(user_ids)
          flash.now[:success] = Spree.t(:customers_removed_from_group, count: deleted_count)
        end
      end

      private

      def set_customer_group
        @customer_group = current_store.customer_groups.find(params[:customer_group_id])
      end

      def model_class
        Spree.user_class
      end

      def scope
        @customer_group.users.includes(:bill_address, :ship_address, avatar_attachment: :blob)
      end

      def collection_includes
        [:bill_address, :ship_address, { avatar_attachment: :blob }]
      end
    end
  end
end
