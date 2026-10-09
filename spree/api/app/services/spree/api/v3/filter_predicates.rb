module Spree
  module Api
    module V3
      # The Ransack predicates the v3 API accepts, per kind of value. Ransack
      # itself would take far more; this is the published contract, so a
      # non-Ruby implementation needs to support exactly these.
      module FilterPredicates
        EQUALITY = %w[eq not_eq in not_in].freeze
        NULLITY = %w[null not_null].freeze
        RANGE = (EQUALITY + %w[lt lteq gt gteq] + NULLITY).freeze

        BY_KIND = {
          'text' => (EQUALITY + %w[cont i_cont not_cont start end] + NULLITY + %w[present blank]).freeze,
          'decimal' => RANGE,
          'integer' => RANGE,
          'date' => RANGE,
          'datetime' => RANGE,
          'enum' => (EQUALITY + NULLITY).freeze,
          'id' => (EQUALITY + NULLITY).freeze,
          'type' => (EQUALITY + NULLITY).freeze,
          'boolean' => (EQUALITY + %w[true false null]).freeze
        }.freeze

        KINDS = BY_KIND.keys.freeze

        # Predicates that take a list of values rather than one.
        LIST = %w[in not_in].freeze

        # Predicates whose value is a flag rather than a value of the
        # attribute's kind (`q[deleted_at_null]=true`).
        FLAG = %w[null not_null present blank true false].freeze

        # @param kind [String] a value kind from {KINDS}
        # @return [Array<String>]
        def self.for(kind)
          BY_KIND.fetch(kind.to_s)
        end
      end
    end
  end
end
