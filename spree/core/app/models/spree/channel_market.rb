module Spree
  class ChannelMarket < Spree.base_class
    belongs_to :channel, class_name: 'Spree::Channel', inverse_of: :channel_markets
    belongs_to :market, class_name: 'Spree::Market'

    validates :market_id, uniqueness: { scope: :channel_id }
    validate :market_belongs_to_channel_store

    private

    # Both sides are store-scoped, so a cross-store row would let one
    # merchant's channel serve another's market.
    def market_belongs_to_channel_store
      return if market.nil? || channel.nil?
      return if market.store_id == channel.store_id

      errors.add(:market, :must_belong_to_same_store)
    end
  end
end
