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
        withdraw_covered_items
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
      # one of them. A profile with per-region origin groups would otherwise
      # allocate to whichever warehouse came first, and when that warehouse's
      # group has no method for the destination the item is dropped as
      # undeliverable even though another warehouse could have shipped it.
      #
      # The caller's order survives within each group, so routing rank and the
      # store's location order still decide between origins that can both
      # deliver.
      def sort_packages
        return if estimator.nil?

        deliverable, @undeliverable_packages = packages.partition { |package| estimator.deliverable?(package) }
        packages.replace(deliverable + @undeliverable_packages)
      end

      # Ordering alone loses to the Adjuster, which takes stock on hand anywhere
      # over a backorder; a unit the capable origins cannot cover stays, so it is
      # still reported as undeliverable rather than lost.
      def withdraw_covered_items
        return if @undeliverable_packages.blank? || @undeliverable_packages.size == packages.size

        supplied = supplied_quantities(packages - @undeliverable_packages)

        @undeliverable_packages.each do |package|
          package.contents.each do |item|
            package.remove_item(item) if supplied[hash_item(item)] >= item.inventory_unit.required_quantity
          end
        end
      end

      def supplied_quantities(packages)
        packages.flat_map(&:contents).each_with_object(Hash.new(0)) do |item, supplied|
          supplied[hash_item(item)] += item.quantity
        end
      end

      def prune_packages
        packages.reject!(&:empty?)
      end

      # A proposed unit has no fulfillment, so its line item keeps two lines of
      # one variant apart; a pair, as XORed ids collide whenever they match.
      def hash_item(item)
        unit = item.inventory_unit
        [unit.variant, unit.fulfillment || unit.line_item_id]
      end
    end
  end
end
