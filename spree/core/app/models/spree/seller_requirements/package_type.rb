# frozen_string_literal: true

module Spree
  module SellerRequirements
    # The seller has told the marketplace what they ship in. Without it their
    # parcels are quoted with the marketplace's box, which is the wrong size
    # and the wrong tare for anyone shipping from their own warehouse — a
    # quote that is wrong rather than missing, so nothing at checkout reveals
    # it (docs/plans/6.0-seller-package-types.md).
    #
    # Measurements, not merely a row: a default box with blank sides quotes
    # the goods alone, which is the silent under-pricing the package type's
    # own guards exist to prevent.
    #
    # Deliberately not satisfied by the marketplace's box, unlike the
    # delivery-method kind beside it: a seller quoting through the operator's
    # shared rates still packs and posts their own parcel. An operator who
    # ships everything themselves switches this requirement off.
    class PackageType < Spree::SellerRequirement
      MEASUREMENTS = %i[length width height weight].freeze

      def met_by_seller?(seller)
        box = seller.default_package_type
        return false if box.nil?

        MEASUREMENTS.all? { |measurement| box.public_send(measurement).to_d.positive? }
      end
    end
  end
end
