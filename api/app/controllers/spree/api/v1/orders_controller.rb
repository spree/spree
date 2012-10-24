module Spree
  module Api
    module V1
      class OrdersController < Spree::Api::V1::BaseController
        before_filter :authorize_read!, :except => [:index, :search, :create]

        def index
          # should probably look at turning this into a CanCan step
          raise CanCan::AccessDenied unless current_api_user.has_spree_role?("admin")
          @orders = Order.page(params[:page]).per(params[:per_page])
        end

        def show
        end

        def search
          @orders = Order.ransack(params[:q]).result.page(params[:page])
          render :index
        end

        def create
          @order = Order.build_from_api(current_api_user, nested_params)
          next!(:status => 201)
        end

        def update
          authorize! :update, Order
          if order.update_attributes(nested_params)
            order.update!
            render :show
          else
            invalid_resource!(order)
          end
        end

        def address
          order.build_ship_address(params[:shipping_address])
          order.build_bill_address(params[:billing_address])
          next!
        end

        def delivery
          begin
            ShippingMethod.find(params[:shipping_method_id])
          rescue ActiveRecord::RecordNotFound
            render :invalid_shipping_method, :status => 422
          else
            order.update_attribute(:shipping_method_id, params[:shipping_method_id])
            next!
          end
        end

        def cancel
          order.cancel!
          render :show
        end

        def empty
          order.line_items.destroy_all
          order.update!
          render :text => nil, :status => 200
        end

        private

        def nested_params
          map_nested_attributes_keys Order, params[:order] || {}
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
end
