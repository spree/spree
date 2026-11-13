module Spree
  module SearchProvider
    # Caps how many index and removal jobs start per second across every
    # store, as set by +Spree::Config.search_index_rate_limit+. A job over the
    # limit waits in the queue without holding a worker thread. Needs the
    # solid_queue-rate_limit gem (0.2.0 or newer) on Solid Queue; elsewhere it
    # does nothing.
    module RateLimited
      extend ActiveSupport::Concern

      included do
        rate = Spree::Config.search_index_rate_limit.to_i
        if rate.positive? && respond_to?(:limits_rate)
          # 0.1.0 has no key: or group:, and would refuse them while the job class loads.
          gem_version = Gem.loaded_specs['solid_queue-rate_limit']&.version
          if gem_version && gem_version < Gem::Version.new('0.2.0')
            raise 'SPREE_SEARCH_INDEX_RATE_LIMIT needs solid_queue-rate_limit 0.2.0 or newer ' \
                  "(#{gem_version} is installed). Update the gem or unset the limit."
          end

          limits_rate to: rate, per: 1.second, burst: [rate, 2].min, key: :global, group: 'spree_search_provider'
        end
      end
    end
  end
end
