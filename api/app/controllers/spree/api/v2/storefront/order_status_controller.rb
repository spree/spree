module Spree
  module Api
    module V2
      module Storefront
        class OrderStatusController < ::Spree::Api::V2::BaseController
          include Spree::Api::V2::Storefront::OrderConcern

          before_action :ensure_order_token

          def show
            render_serialized_payload { serialize_resource(resource) }
          end

          private

          def resource
            resource = resource_finder.new(number: params[:number], token: order_token).execute.take
            raise ActiveRecord::RecordNotFound if resource.nil?

            resource
          end

          def resource_finder
            Spree::Api::Dependencies.storefront_completed_order_finder.constantize
          end

          def resource_serializer
            Spree::Api::Dependencies.storefront_cart_serializer.constantize
          end

          def ensure_order_token
            raise ActiveRecord::RecordNotFound unless order_token
          end
        end
      end
    end
  end
end
