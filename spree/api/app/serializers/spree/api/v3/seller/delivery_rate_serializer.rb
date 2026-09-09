module Spree
  module Api
    module V3
      module Seller
        # A priced service one of this seller's parcels could be carried by.
        #
        # Declared rather than subclassed from the store's rate, which expands
        # the delivery method in full: a seller picks between quotes by name
        # and price, and the method behind one is the operator's arrangement.
        class DeliveryRateSerializer < V3::BaseSerializer
          typelize name: :string,
                   selected: :boolean,
                   cost: :string,
                   display_cost: :string,
                   total: :string,
                   display_total: :string,
                   carrier: [:string, nullable: true],
                   service_level: [:string, nullable: true],
                   estimated_delivery_date: [:string, nullable: true]

          attributes :name, :selected, :cost, :total,
                     :carrier, :service_level, :estimated_delivery_date

          attribute :display_cost do |delivery_rate|
            delivery_rate.display_cost.to_s
          end

          attribute :display_total do |delivery_rate|
            delivery_rate.display_total.to_s
          end
        end
      end
    end
  end
end
