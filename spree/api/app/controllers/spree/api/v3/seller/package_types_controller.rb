module Spree
  module Api
    module V3
      module Seller
        # What this seller packs their goods into: the boxes their parcels
        # ship in, the cartons their products are packed into, the pallets a
        # wholesale order leaves on (docs/plans/6.0-seller-package-types.md).
        #
        # The listing also carries the marketplace's own packaging, so a
        # seller can pack into the operator's standard cartons rather than
        # re-measuring them. Those rows are read-only: `find_resource` roots
        # writes in the seller's own packaging, so a marketplace row's id is a
        # 404 on every action but `show`.
        #
        # Marking a row default makes it the box this seller's parcels are
        # quoted with — one default per owner, so it never displaces the
        # marketplace's.
        class PackageTypesController < Seller::ResourceController
          scoped_resource :package_types

          protected

          def model_class
            Spree::PackageType
          end

          def serializer_class
            Spree.api.seller_package_type_serializer
          end

          # Reading shows the seller's own packaging plus the marketplace's —
          # the same set their variants may reference, so the page answers
          # "what can I pack into" rather than only "what have I measured".
          def scope
            current_store.package_types.
              available_to_seller(current_seller).
              preload_associations_lazily
          end

          # Writes root in the seller's own rows, so the marketplace's
          # packaging cannot be edited or deleted through this branch.
          def resource_scope
            current_seller.package_types
          end

          def find_resource
            action_name == 'show' ? super : resource_scope.find_by_prefix_id!(params[:id])
          end

          # The same set the operator's controller permits — a seller measures
          # their own packaging, so every field on the shared form is theirs
          # to set. `seller_id` is deliberately absent: ownership comes from
          # the authenticated seller, never the payload.
          def resource_permitted_attributes
            [:name, :kind, :length, :width, :height, :dimensions_unit,
             :weight, :max_weight, :weight_unit, :default, { metadata: {} }]
          end
        end
      end
    end
  end
end
