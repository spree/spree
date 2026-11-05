module Spree
  module PaymentMethodRules
    # Offers the method only on the listed channels — invoice for the
    # wholesale channel, cards for retail.
    class ChannelRule < Spree::PaymentMethodRule
      # Accepts prefixed IDs and stores raw ones; the scope confines them to
      # the method's store.
      preference :channel_ids, :array, of: :id, model: 'Spree::Channel', default: [],
                                       scope: ->(rule) { rule.store.channels }

      def eligible?(purchase)
        # An empty preference leaves the method unrestricted, so a
        # half-configured rule fails open.
        return true if preferred_channel_ids.empty?

        preferred_channel_ids.map(&:to_s).include?(purchase.channel_id.to_s)
      end
    end
  end
end
