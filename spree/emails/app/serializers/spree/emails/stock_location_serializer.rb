module Spree
  module Emails
    class StockLocationSerializer < Spree::Api::V3::StockLocationSerializer
      typelize address2: [:string, nullable: true]

      attributes :address2
    end
  end
end
