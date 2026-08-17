# frozen_string_literal: true

module Spree
  module CommissionRules
    # Charge this rate only when the seller is one of these.
    class VendorRule < Spree::CommissionRule
      # Ids are checked against the rate's own store on write, so a rule can
      # never be pointed at another marketplace's seller — and the client is
      # told, rather than having the id quietly dropped.
      preference :vendor_ids, :array, default: [],
                 parse_on_set: normalize_id_preference(
                   klass: Spree::Vendor,
                   scope: ->(rule) { rule.store&.vendors || Spree::Vendor.none }
                 )

      # @return [Array<Spree::Vendor>]
      def vendors
        return [] if preferred_vendor_ids.blank?

        Spree::Vendor.where(id: preferred_vendor_ids)
      end

      def applicable?(context)
        return false if context.vendor.nil?
        # A rule naming nobody narrows nothing, which is what a half-filled
        # form leaves behind — it must not silently charge every seller.
        return false if preferred_vendor_ids.blank?

        preferred_vendor_ids.map(&:to_s).include?(context.vendor.id.to_s)
      end
    end
  end
end
