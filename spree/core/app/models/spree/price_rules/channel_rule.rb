module Spree
  module PriceRules
    class ChannelRule < Spree::PriceRule
      # Stored as raw IDs. Accepts prefixed IDs (`ch_…`) from API
      # callers and decodes them on write so eligibility checks compare
      # against raw `channel_id` rows directly. Scope confines the
      # existence check to the price-list's store so cross-store channel
      # IDs can't sneak in.
      preference :channel_ids, :array, default: [],
                 parse_on_set: normalize_id_preference(
                   klass: Spree::Channel,
                   scope: ->(rule) { rule.store.channels }
                 )

      def channels
        return [] if preferred_channel_ids.blank?

        store.channels.where(id: preferred_channel_ids)
      end

      def applicable?(context)
        # An empty preference means the rule is unrestricted, so it applies
        # regardless of (and even without) a channel in the context.
        return true if preferred_channel_ids.empty?
        return false unless context.channel

        # Compare as strings to support both integer and UUID primary keys
        preferred_channel_ids.map(&:to_s).include?(context.channel.id.to_s)
      end

      def self.description
        Spree.t('price_rules.channel_rule.description')
      end
    end
  end
end
