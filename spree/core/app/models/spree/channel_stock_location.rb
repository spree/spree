module Spree
  class ChannelStockLocation < Spree.base_class
    belongs_to :channel, class_name: 'Spree::Channel', inverse_of: :channel_stock_locations
    belongs_to :stock_location, class_name: 'Spree::StockLocation'

    validates :stock_location_id, uniqueness: { scope: :channel_id }
  end
end
