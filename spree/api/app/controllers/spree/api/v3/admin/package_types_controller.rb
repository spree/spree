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

          request_params :package_type do |body|
            body.attribute :name, :string,
              required: true, on: :create,
              example: 'Euro pallet',
              description: 'Unique within the store.'
            body.attribute :kind, :string,
              required: true, on: :create,
              choices: Spree::PackageType::KINDS,
              example: 'pallet',
              description: 'What this packaging is: the box parcels ship in, or the carton, pallet or container a wholesale order leaves on.'
            body.attribute :length, :number, nullable: true
            body.attribute :width, :number, nullable: true
            body.attribute :height, :number, nullable: true
            body.attribute :dimensions_unit, :string,
              nullable: true,
              choices: Spree::Variant::DIMENSION_UNITS,
              example: 'cm',
              description: "Unit the three dimensions are in; falls back to the store's unit system."
            body.attribute :weight, :number,
              nullable: true,
              description: "The empty package's own weight, added to content weight on every quote."
            body.attribute :max_weight, :number,
              nullable: true,
              description: 'What the package can hold, not the same as its own weight.'
            body.attribute :weight_unit, :string, nullable: true, choices: Spree::Variant::WEIGHT_UNITS, example: 'kg'
            body.attribute :default, :boolean,
              description: 'The box every parcel quote is built on. Setting this demotes whichever row held it.'
            body.attribute :metadata, :hash
          end

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
        end
      end
    end
  end
end
