module Spree
  class StockTransfer < ActiveRecord::Base
    has_many :stock_movements, :as => :originator

    attr_accessible :reference_number

    def transfer(source_location, destination_location, variants)
      transaction do
        variants.each_pair do |variant, quantity|
          source_location.unstock(variant, quantity, self) if source_location
          destination_location.restock(variant, quantity, self)
        end
      end
    end

    def receive(destination_location, variants)
      transfer(nil, destination_location, variants)
    end
  end
end
