module Spree
  module Api
    module V3
      module Admin
        # The store's packaging vocabulary. Marking one row default makes it
        # the box every parcel quote is built on; the model demotes whichever
        # row held the flag before.
        class PackageTypesController < ResourceController
          scoped_resource :settings

          protected

          def model_class
            Spree::PackageType
          end

          def serializer_class
            Spree.api.admin_package_type_serializer
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
