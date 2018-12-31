module Spree
  module Countries
    class Find
      def initialize(scope, params)
        @scope = scope

        @shippable = String(params[:filter][:shippable]) unless params[:filter].nil?
      end

      def call
        countries = by_shippability(scope)

        countries
      end

      private

      attr_reader :shippable, :scope

      def shippable?
        shippable.present?
      end

      def by_shippability(countries)
        return countries unless shippable?

        countries.joins(zones: :shipping_methods).distinct
      end
    end
  end
end
