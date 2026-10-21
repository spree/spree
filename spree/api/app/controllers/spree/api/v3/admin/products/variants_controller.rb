module Spree
  module Api
    module V3
      module Admin
        module Products
          class VariantsController < ResourceController
            scoped_resource :products

            request_params :variant do |body|
              body.extends Spree::Api::V3::Admin::VariantRequestSchema
              body.external_references
              body.require_attributes :options, on: :create
              body.describe_attribute :options, 'One pair per option type the variant takes part in (size, color). Option types and values are created when missing. On update, omit to leave the option values untouched.'
            end

            protected

            def model_class
              Spree::Variant
            end

            def serializer_class
              Spree.api.admin_variant_serializer
            end

            def set_parent
              @parent = current_store.products.find_by_prefix_id!(params[:product_id])
              authorize!(:show, @parent)
            end

            def scope_includes
              [:prices, stock_levels: :stock_location]
            end

            def create_workflow
              Spree.variant_create_workflow
            end

            def update_workflow
              Spree.variant_update_workflow
            end

            # A variant belongs to a product, not directly to a store, and
            # everything nested in the payload is resolved through it — an
            # option value attaches its option type to the product, a stock
            # location is scoped to the product's store.
            def create_workflow_arguments
              { product: @parent, attributes: permitted_params }
            end

            def permitted_params
              params.permit(*permitted_attributes)
            end
          end
        end
      end
    end
  end
end
