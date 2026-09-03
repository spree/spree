module Spree
  module Stock
    class Prioritizer
      attr_reader :packages, :estimator

      # @param packages [Array<Spree::Stock::Package>] candidate packages, in
      #   the order the caller prefers them (routing rank, location order)
      # @param adjuster_class [Class]
      # @param estimator [Spree::Stock::Estimator, nil] consulted for
      #   deliverability, so an origin that cannot serve the destination loses
      #   to one that can. Omitted, the caller's order stands as given.
      def initialize(packages, adjuster_class = Adjuster, estimator: nil)
        @packages = packages
        @adjuster_class = adjuster_class
        @estimator = estimator
        @adjusters = {}
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
            adjuster = build_adjuster(item, package) if adjuster.nil?
            adjuster.adjust(package, item)
          end
        end
      end

      def build_adjuster(item, _package)
        @adjusters[hash_item item] = @adjuster_class.new(item.inventory_unit)
      end

      def find_adjuster(item)
        @adjusters[hash_item item]
      end

      # Origins that can deliver go first, so the Adjuster fills each unit from
      # one of them and the origins that cannot are left empty and pruned. A
      # profile with per-region origin groups would otherwise allocate to
      # whichever warehouse came first, and when that warehouse's group has no
      # method for the destination the item is dropped as undeliverable even
      # though another warehouse could have shipped it.
      #
      # The caller's order survives within each group, so routing rank and the
      # store's location order still decide between origins that can both
      # deliver.
      def sort_packages
        return if estimator.nil?

        ranked = packages.each_with_index.sort_by do |package, index|
          [estimator.deliverable?(package) ? 0 : 1, index]
        end

        packages.replace(ranked.map(&:first))
      end

      def prune_packages
        packages.reject!(&:empty?)
      end

      def hash_item(item)
        shipment = item.inventory_unit.fulfillment
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
