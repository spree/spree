require 'spec_helper'

module Spree
  module Stock
    describe Prioritizer do
      let(:order) { mock_model(Order) }
      let(:stock_location) { build(:stock_location) }
      let(:variant) { build(:variant) }

      def inventory_units
        @inventory_units ||= []
      end

      def build_inventory_unit
        mock_model(InventoryUnit, variant: variant).tap do |unit|
          inventory_units << unit
        end
      end

      def pack
        package = Package.new(order)
        yield(package) if block_given?
        package
      end

      it 'keeps a single package' do
        package1 = pack do |package|
          package.add build_inventory_unit
          package.add build_inventory_unit
        end

        packages = [package1]
        prioritizer = Prioritizer.new(inventory_units, packages)
        packages = prioritizer.prioritized_packages
        packages.size.should eq 1
      end

      it 'removes duplicate packages' do
        package1 = pack do |package|
          package.add build_inventory_unit
          package.add build_inventory_unit
        end

        package2 = pack do |package|
          package.add inventory_units.first
          package.add inventory_units.last
        end

        packages = [package1, package2]
        prioritizer = Prioritizer.new(inventory_units, packages)
        packages = prioritizer.prioritized_packages
        packages.size.should eq 1
      end

      it 'split over 2 packages' do
        package1 = pack do |package|
          package.add build_inventory_unit
        end
        package2 = pack do |package|
          package.add build_inventory_unit
        end

        packages = [package1, package2]
        prioritizer = Prioritizer.new(inventory_units, packages)
        packages = prioritizer.prioritized_packages
        packages.size.should eq 2
      end

      it '1st has some, 2nd has remaining' do
        5.times { build_inventory_unit }

        package1 = pack do |package|
          2.times { |i| package.add inventory_units[i] }
        end
        package2 = pack do |package|
          5.times { |i| package.add inventory_units[i] }
        end

        packages = [package1, package2]
        prioritizer = Prioritizer.new(inventory_units, packages)
        packages = prioritizer.prioritized_packages
        packages.count.should eq 2
        packages[0].quantity.should eq 2
        packages[1].quantity.should eq 3
      end

      it '1st has backorder, 2nd has some' do
        5.times { build_inventory_unit }

        package1 = pack do |package|
          5.times { |i| package.add inventory_units[i], :backordered }
        end
        package2 = pack do |package|
          2.times { |i| package.add inventory_units[i] }
        end

        packages = [package1, package2]
        prioritizer = Prioritizer.new(inventory_units, packages)
        packages = prioritizer.prioritized_packages

        packages[0].quantity(:backordered).should eq 3
        packages[1].quantity(:on_hand).should eq 2
      end

      it '1st has backorder, 2nd has all' do
        5.times { build_inventory_unit }

        package1 = pack do |package|
          3.times { |i| package.add inventory_units[i], :backordered }
        end
        package2 = pack do |package|
          5.times { |i| package.add inventory_units[i] }
        end

        packages = [package1, package2]
        prioritizer = Prioritizer.new(inventory_units, packages)
        packages = prioritizer.prioritized_packages
        packages[0].should eq package2
        packages[1].should be_nil
        packages[0].quantity(:backordered).should eq 0
        packages[0].quantity(:on_hand).should eq 5
      end
    end
  end
end
