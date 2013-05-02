module Spree
  class StockTransfer < ActiveRecord::Base
    has_many :stock_movements, :as => :originator

    belongs_to :source_location, :class_name => 'StockLocation'
    belongs_to :destination_location, :class_name => 'StockLocation'

    has_many :source_movements, :through => :source_location, :source => :stock_movements
    has_many :destination_movements, :through => :destination_location, :source => :stock_movements

    attr_accessible :reference_number

    def number
      reference_number
    end

    def transfer(source_location, destination_location, variants)
      transaction do
        variants.each_pair do |variant, quantity|
          source_location.unstock(variant, quantity, self) if source_location
          destination_location.restock(variant, quantity, self)

          self.source_location = source_location
          self.destination_location = destination_location
          self.save!
        end
      end
    end

    def receive(destination_location, variants)
      transfer(nil, destination_location, variants)
    end
  end
end
