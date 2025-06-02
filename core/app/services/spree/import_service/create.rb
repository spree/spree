module Spree
  module ImportService
    class Create
      ALLOWED_EXT = %w[.csv].freeze
      REQUIRED_HEADERS = %w[sku].freeze

      attr_reader :errors

      def initialize(csv_file:, user_id:, store_id:, type:)
        @csv_file = csv_file
        @user_id = user_id
        @store_id = store_id
        @type = type
        @errors = []
      end

      def call
        validate
        return if errors.present?
        
        Spree::Import.create!(attachment: csv_file, user_id: user_id, store_id: store_id, type: type)
      rescue ActiveRecord::RecordInvalid => error
        @errors << error.message
      end

      private

      attr_reader :csv_file, :user_id, :store_id, :type

      def validate
        @errors << "invalid format" && return unless ALLOWED_EXT.include?(File.extname(csv_file))
        @errors << "missing headers: #{missing_headers.join(', ')}" if missing_headers.present?
      end

      def missing_headers
        @missing_headers ||= (REQUIRED_HEADERS - headers)
      end

      def headers
        ::CSV.foreach(csv_file, headers: false).first
      end
    end
  end
end