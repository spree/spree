module Spree
  module DeliveryMethodRules
    # Offers the method only to carts on the listed channels, so one profile
    # can price the same goods differently per channel (a wholesale rate
    # beside a retail one) without duplicating products or warehouses.
    #
    # This governs which methods a channel is *offered*, not which origins
    # serve it — that stays on the channel's stock-location allowlist, where
    # quoting and allocation cannot disagree
    # (docs/plans/6.0-channel-delivery.md).
    class ChannelRule < Spree::DeliveryMethodRule
      # Stored as raw IDs. Accepts prefixed IDs (`ch_…`) from API callers and
      # decodes them on write, so eligibility compares against raw
      # `channel_id` rows. The scope confines the existence check to the
      # method's store, so cross-store channel IDs can't sneak in.
      preference :channel_ids, :array, default: [],
                 parse_on_set: normalize_id_preference(
                   klass: Spree::Channel,
                   scope: ->(rule) { rule.store.channels }
                 )

      def channels
        return [] if preferred_channel_ids.blank?

        store.channels.where(id: preferred_channel_ids)
      end

      def eligible?(package)
        # An empty preference leaves the method unrestricted, matching the
        # other rules' fail-open convention for half-configured rows.
        return true if preferred_channel_ids.empty?

        channel = package.owner&.channel
        return false if channel.nil?

        # Compare as strings to support both integer and UUID primary keys
        preferred_channel_ids.map(&:to_s).include?(channel.id.to_s)
      end
    end
  end
end
