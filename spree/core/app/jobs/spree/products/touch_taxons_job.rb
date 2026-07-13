module Spree
  module Products
    # Deprecation alias for Spree::Products::TouchCategoriesJob, renamed in 6.0.
    # Kept so any job enqueued under the old class name before the deploy still
    # deserializes; removed in 6.1.
    TouchTaxonsJob = TouchCategoriesJob
  end
end
