module Spree
  module Api
    module V3
      module Admin
        # The store's packaging vocabulary. Marking one row default makes it
        # the box the store's own parcel quotes are built on; the model
        # demotes whichever row held the flag before.
        #
        # On a marketplace this lists every row in the store, the operator's
        # and each seller's, so `q[seller_id_eq]` narrows it to one owner. A
        # row the operator writes here is the marketplace's: `seller_id` is
        # not writable, and a seller's own packaging is theirs to edit through
        # the seller API (docs/plans/6.0-seller-package-types.md).
        class PackageTypesController < ResourceController
          scoped_resource :package_types

          protected

          def model_class
            Spree::PackageType
          end

          def serializer_class
            Spree.api.admin_package_type_serializer
          end

          def collection_includes
            [:seller]
          end

          def resource_permitted_attributes
            [:name, :kind, :length, :width, :height, :dimensions_unit,
             :weight, :max_weight, :weight_unit, :default, { metadata: {} }]
          end
        end
      end
    end
  end
end
