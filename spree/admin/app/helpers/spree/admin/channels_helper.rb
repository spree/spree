module Spree
  module Admin
    module ChannelsHelper
      # Registered +Spree::OrderRouting::Strategy::Base+ subclasses presented in
      # the channel edit form, sourced from the engine registry so the picker
      # can never drift from what the model accepts. A blank value clears the
      # channel-level override and falls back to
      # +Store#preferred_order_routing_strategy+.
      def channel_order_routing_strategy_options
        Spree::OrderRouting::Strategy::Base.registered.map { |strategy| [strategy.display_name, strategy.to_s] }
      end
    end
  end
end
