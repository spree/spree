module Spree
  module Reporting
    # A metric aggregates rows into one number.
    #
    # @!attribute sql
    #   Portable aggregate SQL fragment (no DB-specific functions).
    # @!attribute base
    #   Root relation the aggregate runs against (:orders or :line_items).
    # @!attribute format
    #   :money | :integer | :decimal — :money metrics force a single-currency scope.
    # @!attribute ratio
    #   Derived metrics: [numerator_metric, denominator_metric], computed
    #   post-aggregation per row and for totals.
    Metric = Struct.new(:name, :sql, :base, :format, :ratio, keyword_init: true) do
      def derived? = ratio.present?
      def money? = format == :money
    end

    # A dimension groups rows. The definition owns every behavior keyed off
    # it, so an extension-registered dimension works end-to-end (filtering,
    # hydration, authorization) without touching core.
    #
    # @!attribute base
    #   The finest base able to express this grouping (:orders groupings are
    #   also reachable from :line_items via the order join; not vice versa).
    # @!attribute column
    #   Group-by column (symbol on the base table, or a table-qualified string).
    # @!attribute joins
    #   Extra association joins the grouping needs (from the base relation).
    # @!attribute type
    #   :value | :time — :time dimensions take a grain and zero-fill buckets.
    # @!attribute lookup
    #   Schema tag naming what the dimension's keys identify (e.g. :product) —
    #   set alongside +hydrate+ so clients know display payloads are coming.
    # @!attribute resolve
    #   ->(store, value) resolving filter values (prefixed ids) to raw keys,
    #   always through store-scoped collections. Omitted = values pass through.
    # @!attribute hydrate
    #   ->(store, keys, params) returning { raw_key => { id:, label:, meta: } }
    #   display payloads for the API layer. Omitted = raw keys on the wire.
    # @!attribute subject
    #   -> { SomeClass } authorization subject. JWT admin sessions must be
    #   able to `:read` the class to reference the member; order data itself
    #   is covered by the base Spree::Order check. Lazy so registration never
    #   autoloads models.
    # @!attribute key_scope
    #   API-key scope (e.g. 'read_products') required alongside `read_reports`
    #   for secret keys to reference the member. Mandatory whenever `subject`
    #   is declared, so key access is decided at registration, never skipped.
    Dimension = Struct.new(:name, :base, :column, :joins, :type, :grains, :lookup,
                           :resolve, :hydrate, :subject, :key_scope, keyword_init: true) do
      def time? = type == :time
    end

    # Allowlist of queryable metrics + dimensions. One global instance lives at
    # `Spree.reporting`; core seeds the starter vocabulary in the engine
    # initializer and applications/extensions append theirs in initializer files.
    class Registry
      attr_reader :metrics, :dimensions

      def initialize
        @metrics = {}
        @dimensions = {}
      end

      def metric(name, replace: false, **opts)
        name = name.to_sym
        raise ArgumentError, "metric #{name} already registered (pass replace: true to override)" if @metrics.key?(name) && !replace

        opts[:format] ||= :integer
        @metrics[name] = Metric.new(name: name, **opts)
      end

      def dimension(name, replace: false, **opts)
        name = name.to_sym
        raise ArgumentError, "dimension #{name} already registered (pass replace: true to override)" if @dimensions.key?(name) && !replace
        if opts[:subject] && opts[:key_scope].blank?
          raise ArgumentError, "dimension #{name} declares a subject and must also declare its key_scope"
        end

        opts[:type] ||= :value
        @dimensions[name] = Dimension.new(name: name, **opts)
      end

      def metric!(name)
        @metrics[name.to_sym] || raise(UnknownMember.new(:metric, name, @metrics.keys))
      end

      def dimension!(name)
        @dimensions[name.to_sym] || raise(UnknownMember.new(:dimension, name, @dimensions.keys))
      end

      # Serializable introspection payload — drives `GET /reporting/schema`,
      # admin pickers, and the AI tool schema.
      def schema
        {
          metrics: @metrics.values.map { |m| { name: m.name, format: m.format, derived: m.derived? } },
          dimensions: @dimensions.values.map do |d|
            { name: d.name, type: d.type, grains: d.grains, lookup: d.lookup }.compact
          end
        }
      end
    end
  end
end
