module Spree
  module DeliveryMethodRules
    # Bounds the method by the packed volume of the shipment, in cubic
    # meters. This is what turns a wholesale tier table into configuration: a
    # "Pallet" method takes 1–15 CBM, a "20ft container" 15–33, and the
    # estimator offers whichever one the order actually fills.
    #
    # Unlike {WeightRule}, the compared value is always converted to CBM
    # first. Dimensions are stored in whatever unit the merchant typed, and
    # inches read as centimeters overstate a carton roughly sixteenfold — too
    # large an error to leave to convention.
    class VolumeRule < Spree::DeliveryMethodRule
      preference :minimum_volume, :decimal, default: nil, nullable: true
      preference :maximum_volume, :decimal, default: nil, nullable: true

      def eligible?(package)
        summary = package.freight_summary
        volume = summary.total_volume

        # A partly measured catalog understates the load — wholly unmeasured
        # goods roll up to zero, and one measured SKU among five reports a
        # fraction of the truth. Either way the figure is a floor, not a
        # measurement, so it may raise a shipment into a tier but never
        # exclude it from one: failing a minimum on an understated volume
        # hides the method from exactly the order it was built for, with
        # nothing for the merchant to see. A maximum still applies, since
        # passing one on too small a number errs toward offering the method.
        return false if preferred_minimum_volume.present? && summary.complete? && volume < preferred_minimum_volume
        return false if preferred_maximum_volume.present? && volume > preferred_maximum_volume

        true
      end
    end
  end
end
