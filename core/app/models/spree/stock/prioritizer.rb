module Spree
  module Stock
    class Prioritizer
      attr_reader :packages

      def initialize(packages, adjuster_class=Adjuster)
        @packages = packages
        @adjuster_class = adjuster_class
        @adjusters = Hash.new
      end

      def prioritized_packages
        sort_packages
        adjust_packages
        prune_packages
        packages
      end

      private

      def adjust_packages
        packages.each do |package|
          package.contents.each do |item|
            adjuster = find_adjuster(item)
            if adjuster.nil?
              adjuster = build_adjuster(item, package)
            end
            adjuster.adjust(package, item)
          end
        end
      end

      def build_adjuster(item, package)
        @adjusters[hash_item item] = @adjuster_class.new(item.inventory_unit)
      end

      def find_adjuster(item)
        @adjusters[hash_item item]
      end

      def sort_packages
        # order packages by preferred stock_locations
      end

      def prune_packages
        packages.reject! { |pkg| pkg.empty? }
      end

      def hash_item(item)
        shipment = item.inventory_unit.shipment
        variant  = item.inventory_unit.variant
        if shipment.present?
          variant.hash ^ shipment.hash
        else
          variant.hash
        end
      end
    end
  end
end
