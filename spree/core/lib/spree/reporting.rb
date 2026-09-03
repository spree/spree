require 'spree/reporting/registry'
require 'spree/reporting/default_vocabulary'
require 'spree/reporting/query'
require 'spree/reporting/result'
require 'spree/reporting/adapters/base'
require 'spree/reporting/adapters/live'

module Spree
  # Semantic reporting layer (see docs/plans/6.0-analytics-semantic-layer.md).
  #
  # Developers extend the vocabulary through the registry:
  #
  #   Spree.reporting.metric :wholesale_margin, sql: '...', base: :line_items, format: :money
  #   Spree.reporting.dimension :warehouse, base: :orders, column: :stock_location_id, lookup: 'Spree::StockLocation'
  #
  # Consumers (Admin API, dashboard, saved reports, AI tools) compose queries
  # against registered names only — see Spree::Reporting::Query.
  module Reporting
    class UnknownMember < StandardError
      attr_reader :kind, :name, :valid

      def initialize(kind, name, valid)
        @kind = kind
        @name = name
        @valid = valid
        super("Unknown reporting #{kind}: #{name}. Valid #{kind.to_s.pluralize}: #{valid.join(', ')}")
      end
    end

    class InvalidQuery < StandardError; end
  end
end
