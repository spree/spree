module Spree
  module Api
    module V2
      module Storefront
        module Account
          class OrdersController < ::Spree::Api::V2::ResourceController
            before_action :require_spree_current_user

            private

            def collection
              collection_finder.new(user: spree_current_user).execute
            end

            def resource
              resource = resource_finder.new(user: spree_current_user, number: params[:id]).execute.take
              raise ActiveRecord::RecordNotFound if resource.nil?

              resource
            end

            def allowed_sort_attributes
              super << :completed_at
            end

            def collection_serializer
              Spree::Api::Dependencies.storefront_order_serializer.constantize
            end

            def resource_serializer
              Spree::Api::Dependencies.storefront_order_serializer.constantize
            end

            def collection_finder
              Spree::Api::Dependencies.storefront_completed_order_finder.constantize
            end

            def resource_finder
              Spree::Api::Dependencies.storefront_completed_order_finder.constantize
            end
          end
        end
      end
    end
  end
end
