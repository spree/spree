module Spree
  module Addresses
    class Find < ::Spree::BaseFinder
      def initialize(scope:, params:)
        super
        @exclude_quick_checkout = params.dig(:filter, :exclude_quick_checkout)
      end

      def execute
        addresses = scope
        exclude_quick_checkout(addresses)
      end

      private

      def exclude_quick_checkout?
        @exclude_quick_checkout.present?
      end

      def exclude_quick_checkout(addresses)
        return addresses unless exclude_quick_checkout?

        addresses.not_quick_checkout
      end
    end
  end
end
