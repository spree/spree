module Spree
  module Countries
    class Find < ::Spree::BaseFinder
      def initialize(scope:, params:)
        @scope = scope

        @shippable = String(params[:filter][:shippable]) unless params[:filter].nil?
      end

      def call
        ActiveSupport::Deprecation.warn(<<-DEPRECATION, caller)
          Spree::Countries::Find.new.call is deprecated and will be removed in Spree 5.0.
          Please use Spree::Countries::Find.new.execute instead
        DEPRECATION
        execute
      end

      def execute
        countries = by_shippability(scope)

        countries
      end

      private

      attr_reader :shippable

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
