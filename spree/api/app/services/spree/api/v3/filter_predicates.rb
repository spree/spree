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
        IDENTITY = (EQUALITY + NULLITY).freeze

        BY_KIND = {
          'text' => (EQUALITY + %w[cont i_cont not_cont start end] + NULLITY + %w[present blank]).freeze,
          'decimal' => RANGE,
          'integer' => RANGE,
          'date' => RANGE,
          'datetime' => RANGE,
          'enum' => IDENTITY,
          'id' => IDENTITY,
          'type' => IDENTITY,
          'boolean' => (EQUALITY + %w[true false null]).freeze
        }.freeze

        KINDS = BY_KIND.keys.freeze
      end
    end
  end
end
