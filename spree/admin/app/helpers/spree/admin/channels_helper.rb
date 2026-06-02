module Spree
  module Admin
    module ChannelsHelper
      # Concrete +Spree::OrderRouting::Strategy::Base+ subclasses presented in
      # the channel edit form. A blank value clears the channel-level override
      # and falls back to +Store#preferred_order_routing_strategy+.
      def channel_order_routing_strategy_options
        [
          [Spree.t('admin.channels.order_routing_strategies.rules'),    'Spree::OrderRouting::Strategy::Rules'],
          [Spree.t('admin.channels.order_routing_strategies.reducer'),  'Spree::OrderRouting::Strategy::Reducer'],
          [Spree.t('admin.channels.order_routing_strategies.legacy'),   'Spree::OrderRouting::Strategy::Legacy']
        ]
      end
    end
  end
end
