module Spree
  module Admin
    class CustomerGroupsController < ResourceController
      add_breadcrumb_icon 'users'
      add_breadcrumb Spree.t(:customer_groups), :admin_customer_groups_path

      skip_before_action :load_resource, only: [:select_options]

      def select_options
        q = params[:q]
        ransack_params = q.is_a?(String) ? { name_cont: q } : q
        customer_groups = current_store.customer_groups.ransack(ransack_params).result.order(:name).limit(50)

        render json: customer_groups.pluck(:id, :name).map { |id, name| { id: id, name: name } }
      end

      def show
        add_breadcrumb @customer_group.name
      end

      private

      def location_after_create
        spree.admin_customer_group_path(@customer_group)
      end

      def update_turbo_stream_enabled?
        true
      end

      def model_class
        Spree::CustomerGroup
      end

      def collection
        return @collection if defined?(@collection)

        @collection = super.for_store(current_store)
      end

      def permitted_resource_params
        params.require(:customer_group).permit(permitted_customer_group_attributes)
      end
    end
  end
end
