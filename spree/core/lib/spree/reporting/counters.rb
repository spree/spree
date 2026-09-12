module Spree
  module Reporting
    # Evaluates the registered counters for one store, filtered to those the
    # caller may read. Carries no copy: a counter is identified by its key and
    # the client owns every string it shows, so an interface in one language
    # never renders a number labelled in another.
    class Counters
      # @param store [Spree::Store]
      # @param channel [Spree::Channel, nil] narrows order-derived counts; nil means all channels
      # @param registry [Registry]
      # @param allowed [Proc] ->(counter) { true/false } — the same permission
      #   gate the schema applies to metrics and dimensions
      def initialize(store:, channel: nil, registry: Spree.reporting, allowed: ->(_counter) { true })
        @store = store
        @channel = channel
        @registry = registry
        @allowed = allowed
      end

      # @return [Array<CounterResult>] in registration order
      def to_a
        @registry.counters.values.select { |counter| @allowed.call(counter) }.map do |counter|
          CounterResult.new(
            key: counter.name,
            value: counter.count.call(@store, channel: @channel),
            link: counter.link&.deep_stringify_keys,
            nav: counter.nav
          )
        end
      end
    end
  end
end
