module Spree
  # A carrier a consignment or a label is pinned to.
  #
  # The value is free text by design: +Spree.tracking_carriers+ supplies
  # display names and tracking-page templates for the carriers Spree knows,
  # and anything else — a freight forwarder, a courier a merchant uses once —
  # is a legal value that simply has no entry.
  module HasTrackingCarrier
    extend ActiveSupport::Concern

    # @return [String, nil] the registry's display name, or the value as entered
    def carrier_name
      return if carrier.blank?

      Spree.tracking_carriers.dig(carrier, :name) || carrier
    end
  end
end
