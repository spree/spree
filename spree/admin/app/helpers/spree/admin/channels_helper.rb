module Spree
  module Admin
    module ChannelsHelper
      # Registered +Spree::OrderRouting::Strategy::Base+ subclasses presented in
      # the channel edit form, sourced from +Spree.order_routing.strategies+ so the
      # picker can never drift from what the model accepts. A blank value clears the
      # channel-level override and falls back to
      # +Store#preferred_order_routing_strategy+.
      def channel_order_routing_strategy_options
        Spree.order_routing.strategies.map { |strategy| [strategy.display_name, strategy.to_s] }
      end

      # Storefront access levels for the channel edit form. A blank selection
      # clears the channel override and falls back to +Store#preferred_storefront_access+.
      def channel_storefront_access_options
        Spree::Channel::Gating::STOREFRONT_ACCESS.map do |value|
          [Spree.t("admin.channels.storefront_access_options.#{value}"), value]
        end
      end

      # Tri-state guest-checkout override for the channel edit form. A blank
      # selection clears the override and falls back to +Store#preferred_guest_checkout+.
      def channel_guest_checkout_options
        [
          [Spree.t('admin.channels.guest_checkout_allowed'), 'true'],
          [Spree.t('admin.channels.guest_checkout_blocked'), 'false']
        ]
      end
    end
  end
end
