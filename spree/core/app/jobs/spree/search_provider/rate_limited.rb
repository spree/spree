module Spree
  module SearchProvider
    # Caps how many index and removal jobs start per second across every
    # store, as set by +Spree::Config.search_index_rate_limit+. A job over the
    # limit waits in the queue without holding a worker thread. Needs the
    # solid_queue-rate_limit gem on Solid Queue; elsewhere it does nothing.
    module RateLimited
      extend ActiveSupport::Concern

      included do
        rate = Spree::Config.search_index_rate_limit.to_i
        if rate.positive? && respond_to?(:limits_rate)
          limits_rate to: rate, per: 1.second, burst: [rate, 2].min, key: :global, group: 'spree_search_provider'
        end
      end
    end
  end
end
