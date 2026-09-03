require 'spree/reporting/registry'
require 'spree/reporting/default_vocabulary'
require 'spree/reporting/query'
require 'spree/reporting/schema'
require 'spree/reporting/result'
require 'spree/reporting/hydration'
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
    # Public URL for a media row a hydrated dimension carries, or nil when the
    # record has no file. Mirrors what the API serializers render.
    #
    # @param media [Spree::Media, nil]
    # @return [String, nil]
    def self.image_url(media)
      attachment = media.respond_to?(:attachment) ? media.attachment : media
      return nil unless attachment.respond_to?(:attached?) && attachment.attached?

      Rails.application.routes.url_helpers.cdn_image_url(attachment)
    end

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
