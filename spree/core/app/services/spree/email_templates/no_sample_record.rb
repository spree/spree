module Spree
  module EmailTemplates
    # The store has no record to build an email's sample data from, so it
    # cannot be previewed with data yet.
    class NoSampleRecord < StandardError; end
  end
end
