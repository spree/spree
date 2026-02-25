module Spree
  module Seeds
    class All
      prepend Spree::ServiceModule::Base

      def call
        Spree::Events.disable do
          # GEO
          Countries.call
          States.call
          Zones.call

          # user roles
          Roles.call

          # additional data
          ReturnsEnvironment.call
          ShippingCategories.call
          StoreCreditCategories.call
          TaxCategories.call
          DigitalDelivery.call

          # store & stock location
          Stores.call
          StockLocations.call
          AdminUser.call

          # add store resources
          PaymentMethods.call
          ApiKeys.call
        end
      end
    end
  end
end
