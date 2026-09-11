module Spree
  module Reporting
    # Evaluates the registered counters for one store, filtered to those the
    # caller may read. Labels resolve through the locale the way the schema
    # resolves metric labels, so an extension's counter needs no dashboard
    # release to show up with a name.
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
            label: translate(counter.name, :label) || counter.name.to_s.humanize,
            description: description_for(counter),
            value: counter.count.call(@store, channel: @channel),
            link: counter.link&.deep_stringify_keys,
            nav: counter.nav
          )
        end
      end

      private

      def description_for(counter)
        return counter.description.call(@store) if counter.description.respond_to?(:call)

        translate(counter.name, :description)
      end

      def translate(name, facet)
        Spree.t("reporting.counters.#{name}.#{facet}", default: nil)
      end
    end
  end
end
