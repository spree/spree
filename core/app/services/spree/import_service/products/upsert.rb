module Spree
  module ImportService
    module Products
      class Upsert
        def initialize(row:)
          @row = row.symbolize_keys!
        end

        def call
          already_exists? ? update : create
        end

        private

        attr_reader :row

        def already_exists?
          Spree::Variant.exists?(sku: row[:sku])
        end

        def update
          ActiveRecord::Base.transaction do
            ImportService::Products::Update.new(row: row).call
          end
        end

        def create
          ActiveRecord::Base.transaction do
            Spree::ImportService::Products::Create.new(row: row).call
          end
        end
      end
    end
  end
end