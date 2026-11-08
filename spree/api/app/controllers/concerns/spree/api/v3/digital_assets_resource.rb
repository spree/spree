module Spree
  module Api
    module V3
      # The downloadable files on one product, shared by the operator's and a
      # seller's branch. Writes run through the digital asset workflows; each
      # includer finds and authorizes the product in `set_parent`, names its
      # serializer, and may add to the workflow arguments.
      module DigitalAssetsResource
        extend ActiveSupport::Concern

        protected

        def model_class
          Spree::DigitalAsset
        end

        # Assets reach the product through `variants`, whose ORDER BY
        # PostgreSQL rejects alongside the collection's DISTINCT.
        def scope
          super.reorder(created_at: :asc)
        end

        def scope_includes
          [:variant, { attachment_attachment: :blob }]
        end

        # Not normalized: `provider_settings` may hold values shaped like
        # prefixed ids.
        def permitted_params
          params.permit(*declared_permitted_attributes, *model_additional_permitted_attributes)
        end

        def create_workflow
          Spree.digital_asset_create_workflow
        end

        def update_workflow
          Spree.digital_asset_update_workflow
        end

        # An asset belongs to a variant, not directly to a store; the workflow
        # resolves the variant through the product.
        def create_workflow_arguments
          { product: @parent, attributes: workflow_attributes }
        end

        def update_workflow_arguments
          { digital_asset: @resource, attributes: workflow_attributes }
        end

        private

        # `signed_id` and `variant_id` are declared `permit: false` because
        # neither is a column: the workflow attaches the one and resolves the
        # other through the product, so they travel beside the attributes.
        def workflow_attributes
          permitted_params.to_h.merge(params.permit(:signed_id, :variant_id).to_h)
        end

        # Only authorized, never saved: the workflow builds the record it
        # writes. The variant is what an ability's conditions read.
        def build_resource
          model_class.new(variant: @parent.default_variant)
        end
      end
    end
  end
end
