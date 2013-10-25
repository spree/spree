module Spree
  module Api
    class OrdersController < Spree::Api::BaseController
      respond_to :json

      before_filter :authorize_read!, :except => [:index, :search, :create]

      def index
        # should probably look at turning this into a CanCan step
        raise CanCan::AccessDenied unless current_api_user.has_spree_role?("admin")
        @orders = Order.ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
        respond_with(@orders)
      end

      def show
        respond_with(@order)
      end

      def create
        nested_params[:line_items_attributes] = sanitize_line_items(nested_params[:line_items_attributes])
        @order = Order.build_from_api(current_api_user, nested_params)
        respond_with(order, :default_template => :show, :status => 201)
      end

      def update
        authorize! :update, Order
        # Parsing line items through as an update_attributes call in the API will result in
        # many line items for the same variant_id being created. We must be smarter about this,
        # hence the use of the update_line_items method, defined within order_decorator.rb.
        line_items_params = sanitize_line_items(nested_params.delete("line_items_attributes"))
        if order.update_attributes(nested_params)
          order.update_line_items(line_items_params)
          order.line_items.reload
          order.update!
          respond_with(order, :default_template => :show)
        else
          invalid_resource!(order)
        end
      end

      def cancel
        order.cancel!
        render :show
      end

      def empty
        order.empty!
        order.update!
        render :text => nil, :status => 200
      end

      private

      def nested_params
        @nested_params ||= map_nested_attributes_keys(Order, params[:order] || {})
      end

      def sanitize_line_items(line_item_attributes)
        return {} if line_item_attributes.blank?
        line_item_attributes = line_item_attributes.map do |id, attributes|
          # Faux Strong-Parameters code to strip price if user isn't an admin
          if current_api_user.has_spree_role?("admin")
            [id, attributes.slice(*Spree::LineItem.attr_accessible[:api])]
          else
            [id, attributes.slice(*Spree::LineItem.attr_accessible[:default])]
          end
        end
        line_item_attributes = Hash[line_item_attributes].delete_if { |k,v| v.empty? }
      end

      def order
        @order ||= Order.find_by_number!(params[:id])
      end

      def next!(options={})
        if @order.valid? && @order.next
          render :show, :status => options[:status] || 200
        else
          render :could_not_transition, :status => 422
        end
      end

      def authorize_read!
        authorize! :read, order
      end
    end
  end
end
