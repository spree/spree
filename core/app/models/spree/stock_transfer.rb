module Spree
  class StockTransfer < ActiveRecord::Base
    attr_accessible :destination_location_id, :source_location_id, :type

    has_many :stock_movements, :as => :originator

    def transfer(source_location, destination_location, variants)
      transaction do
        variants.each_pair do |variant, quantity|
          source_location.unstock(variant, quantity, self)
          destination_location.restock(variant, quantity, self)
        end
      end
    end
  end
end
