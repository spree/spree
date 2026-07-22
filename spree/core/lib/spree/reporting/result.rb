module Spree
  module Reporting
    # Adapter output. All values are numeric (BigDecimal/Integer) — display
    # formatting is the API layer's job.
    #
    # totals: { metric_name => { value:, previous:, growth: } }
    # rows:   [ { dimensions: { dim_name => raw_key }, metrics: { metric_name => { value:, previous:, growth: } } } ]
    Result = Struct.new(:meta, :totals, :rows, keyword_init: true)
  end
end
