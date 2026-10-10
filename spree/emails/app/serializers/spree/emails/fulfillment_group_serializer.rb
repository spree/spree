module Spree
  module Emails
    # One real parcel of a purchase: what it carries, who sold it and what it
    # cost to deliver.
    class FulfillmentGroupSerializer
      include Alba::Resource

      attributes :name

      # A freight parcel awaiting its forwarder's quote has no cost yet.
      attribute :unpriced, &:unpriced?

      attribute :cost do |group|
        Spree::Money::Rounding.format(group.cost, group.currency)
      end

      attribute :display_cost do |group|
        group.display_cost.to_s
      end

      attribute :seller_names do |group|
        group.sellers.map(&:name)
      end

      many :manifest, key: :items, source: proc { manifest.select(&:line_item) },
                     resource: Spree::Emails::ParcelItemSerializer
    end
  end
end
