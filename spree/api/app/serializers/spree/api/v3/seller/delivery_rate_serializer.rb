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
                   carrier: [:string, nullable: true],
                   service_level: [:string, nullable: true],
                   estimated_delivery_date: [:string, nullable: true],
                   unpriced: :boolean

          attributes :name, :selected

          money_attributes :cost, :total

          attributes :carrier, :service_level, :estimated_delivery_date, :unpriced

          typelize cost: [:string, nullable: false],
                   total: [:string, nullable: false]
        end
      end
    end
  end
end
