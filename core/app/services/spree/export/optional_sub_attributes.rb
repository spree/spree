module Spree
  module Export
    class OptionalSubAttributes
      prepend Spree::ServiceModule::Base

      def call(input)
        information = {}

        return failure(information, error: 'Not implemented') if information.empty?

        # This is a place where you can put attributes that have sub-attributes, example for shipping:
        #
        # information['shipping'] = {}
        # information['shipping']['price'] = calculate_shipping(input[:product])
        # information['shipping']['country'] = input[:store].default_country

        success(information: information)
      end
    end
  end
end
