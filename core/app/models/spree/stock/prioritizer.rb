module Spree
  module Stock
    class Prioritizer
      attr_reader :packages, :inventory_units

      def initialize(inventory_units, packages, adjuster_class=Adjuster)
        @inventory_units = inventory_units
        @packages = packages
        @adjuster_class = adjuster_class
      end

      def prioritized_packages
        sort_packages
        adjust_packages
        prune_packages
        packages
      end

      private
      def adjust_packages
        inventory_units.each do |inventory_unit|
          adjuster = @adjuster_class.new(inventory_unit, :on_hand)

          visit_packages(adjuster)

          adjuster.status = :backordered
          visit_packages(adjuster)
        end
      end

      def visit_packages(adjuster)
        packages.each do |package|
          item = package.find_item adjuster.inventory_unit, adjuster.status
          adjuster.adjust(package) if item
        end
      end

      def sort_packages
        # order packages by preferred stock_locations
      end

      def prune_packages
        packages.reject! { |pkg| pkg.empty? }
      end
    end
  end
end
