require 'pagy'

module Spree
  module Api
    class Paginate
      include Pagy::Method

      def initialize(collection, params)
        @collection = collection
        @params = params

        per_page_limit = Spree::Api::Config[:api_v2_per_page_limit]
        @per_page = if params[:per_page].to_i.between?(1, per_page_limit)
                      params[:per_page].to_i
                    else
                      25
                    end
      end

      def call
        # Pass params as a hash-based request object for Pagy
        # Pagy::Request accepts a hash with :params key
        # Use to_unsafe_h for ActionController::Parameters, fallback to to_h for regular hashes
        params_hash = @params.respond_to?(:to_unsafe_h) ? @params.to_unsafe_h : @params.to_h
        request_hash = { params: params_hash }

        sql = @collection.to_sql
        has_grouping = sql.include?(' HAVING ') || sql.include?(' GROUP BY ')

        if has_grouping
          # Use offset paginator with count_over for GROUP BY/HAVING queries
          # count_over uses COUNT(*) OVER () which works with grouped collections
          pagy, records = pagy(:offset, @collection, limit: @per_page, request: request_hash, count_over: true)
        else
          # Uses countish paginator which is faster as it avoids COUNT queries
          pagy, records = pagy(:countish, @collection, limit: @per_page, request: request_hash)
        end

        PagyCollection.new(records, pagy)
      end
    end

    # Wrapper providing Kaminari-compatible interface for CollectionOptionsHelpers
    # Includes Enumerable so jsonapi-serializer detects it as a collection
    class PagyCollection < SimpleDelegator
      include Enumerable

      attr_reader :pagy

      def initialize(records, pagy)
        super(records)
        @pagy = pagy
      end

      # Enumerable requires #each to be defined
      def each(&block)
        __getobj__.each(&block)
      end

      def next_page
        @pagy.next
      end

      def prev_page
        @pagy.previous
      end

      def total_pages
        @pagy.pages
      end

      def total_count
        @pagy.count
      end
    end
  end
end
