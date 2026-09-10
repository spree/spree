module Spree
  module Reporting
    # A metric aggregates rows into one number.
    #
    # @!attribute sql
    #   Portable aggregate SQL fragment (no DB-specific functions).
    # @!attribute base
    #   Root relation the aggregate runs against (:orders or :line_items).
    # @!attribute format
    #   :money | :integer | :decimal | :percent — :money metrics force a
    #   single-currency scope; :percent metrics arrive as the number a merchant
    #   reads (42.5), not the fraction.
    # @!attribute ratio
    #   Derived metrics: [numerator_metric, denominator_metric], computed
    #   post-aggregation per row and for totals.
    # @!attribute subject
    #   Callable returning the model class a caller must be able to read for
    #   this number — for a metric that exposes money outside the order itself,
    #   like the marketplace's commission. Declared with key_scope.
    # @!attribute key_scope
    #   API-key scope the same number requires.
    Metric = Struct.new(:name, :sql, :base, :format, :ratio, :subject, :key_scope, keyword_init: true) do
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
    # @!attribute values
    #   Enumerable raw values for status-like dimensions (an Array, or a lambda
    #   returning one so model constants load lazily). Published in the schema
    #   as the filter value list.
    Dimension = Struct.new(:name, :base, :column, :expression, :joins, :type, :grains, :lookup,
                           :resolve, :hydrate, :subject, :key_scope, :values, keyword_init: true) do
      def time? = type == :time

      # A dimension whose key is computed rather than read from a column. The
      # compiler validates `column` down to `table.column` so registration
      # cannot smuggle SQL by accident; `expression` is how a developer says
      # the SQL is deliberate, and it carries the same trust as a metric's.
      def expression? = expression.present?

      def enumerated_values
        values.respond_to?(:call) ? values.call : values
      end
    end

    # A relation metrics aggregate over, and the family it belongs to.
    #
    # Bases exist because the things a store measures sit at different grains:
    # an order has no payment method, a payment has no line items, a stock
    # movement has neither a customer nor a currency. A base names one grain,
    # says how to reach it store-scoped, and declares which family it can be
    # queried alongside.
    #
    # @!attribute family
    #   Bases sharing a family combine in one query (:orders and :line_items
    #   both answer questions about sales). Bases in different families never
    #   do — the query refuses the mix rather than inventing a join between
    #   grains that have no honest relationship.
    # @!attribute relation
    #   ->(store, range, currency) returning the store-scoped, range-filtered
    #   relation. Money bases filter the currency; countable ones ignore it.
    # @!attribute table
    #   The base's own table, as a %{placeholder}. Where a bare `column:`
    #   symbol on one of its dimensions is read from. Deliberately separate
    #   from time_column: a line item's clock lives on its order.
    # @!attribute time_column
    #   Table-qualified column the range filters on, named in the schema so a
    #   caller knows what "last 30 days" means for this base.
    # @!attribute reaches
    #   Bases whose dimensions this one can group by, itself included. An
    #   :orders dimension is reachable from :line_items through the order join;
    #   not the reverse.
    Base = Struct.new(:name, :family, :table, :relation, :time_column, :reaches, keyword_init: true) do
      def reaches?(dimension_base) = Array(reaches).include?(dimension_base)
    end

    # Allowlist of queryable metrics + dimensions. One global instance lives at
    # `Spree.reporting`; core seeds the starter vocabulary in the engine
    # initializer and applications/extensions append theirs in initializer files.
    class Registry
      attr_reader :metrics, :dimensions, :bases

      def initialize
        @metrics = {}
        @dimensions = {}
        @bases = {}
      end

      # @param name [Symbol]
      # @param family [Symbol] bases sharing a family combine in one query
      # @param table [String] the base's own table as a %{placeholder}
      # @param relation [Proc] ->(store, range, currency) → store-scoped relation
      # @param time_column [String] table-qualified column the range filters on
      # @param reaches [Array<Symbol>] bases whose dimensions this one can group by
      def base(name, replace: false, family:, table:, relation:, time_column:, reaches: nil)
        name = name.to_sym
        raise ArgumentError, "base #{name} already registered (pass replace: true to override)" if @bases.key?(name) && !replace

        @bases[name] = Base.new(name: name, family: family, table: table, relation: relation,
                                time_column: time_column, reaches: reaches || [name])
      end

      def base!(name)
        @bases[name.to_sym] || raise(UnknownMember.new(:base, name, @bases.keys))
      end

      def metric(name, replace: false, **opts)
        name = name.to_sym
        raise ArgumentError, "metric #{name} already registered (pass replace: true to override)" if @metrics.key?(name) && !replace
        if opts[:subject] && opts[:key_scope].blank?
          raise ArgumentError, "metric #{name} declares a subject and must also declare its key_scope"
        end

        opts[:format] ||= :integer
        @metrics[name] = Metric.new(name: name, **opts)
      end

      def dimension(name, replace: false, **opts)
        name = name.to_sym
        raise ArgumentError, "dimension #{name} already registered (pass replace: true to override)" if @dimensions.key?(name) && !replace
        if opts[:subject] && opts[:key_scope].blank?
          raise ArgumentError, "dimension #{name} declares a subject and must also declare its key_scope"
        end

        if opts[:column].blank? && opts[:expression].blank?
          raise ArgumentError, "dimension #{name} needs a column or an expression"
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

      # Whether a metric can be grouped or filtered by a dimension: every
      # aggregated component of the metric must sit on a base that reaches the
      # dimension's base. Order totals per product would double count, so
      # :orders does not reach :line_items; the reverse holds through the order
      # join. The single rule the schema and the compiler share.
      #
      # @param metric [Metric]
      # @param dimension [Dimension]
      # @return [Boolean]
      def compatible?(metric, dimension)
        components(metric).all? { |component| base!(component.base).reaches?(dimension.base) }
      end

      # A derived metric aggregates nothing itself — its components do.
      def components(metric)
        metric.derived? ? metric.ratio.map { |name| metric!(name) } : [metric]
      end

      # The family a metric belongs to, read through its components so a
      # derived metric answers with its ingredients' family rather than nil.
      def family_of(metric)
        base!(components(metric).first.base).family
      end

    end
  end
end
