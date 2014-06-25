require 'spec_helper'

module Spree
  module Stock
    describe Prioritizer do
      let(:order) { create(:order_with_line_items, line_items_count: 2) }
      let(:stock_location) { build(:stock_location) }

      let(:line_item1) { order.line_items[0] }
      let(:line_item2) { order.line_items[1] }

      def pack
        package = Package.new(order, stock_location)
        yield(package) if block_given?
        package
      end

      it 'keeps a single package' do
        package1 = pack do |package|
          package.add line_item1, 1, :on_hand
          package.add line_item2, 1, :on_hand
        end

        packages = [package1]
        prioritizer = Prioritizer.new(order, packages)
        packages = prioritizer.prioritized_packages
        packages.size.should eq 1
      end

      it 'removes duplicate packages' do
        package1 = pack do |package|
          package.add line_item1, 1, :on_hand
          package.add line_item2, 1, :on_hand
        end
        package2 = pack do |package|
          package.add line_item1, 1, :on_hand
          package.add line_item2, 1, :on_hand
        end

        packages = [package1, package2]
        prioritizer = Prioritizer.new(order, packages)
        packages = prioritizer.prioritized_packages
        packages.size.should eq 1
      end

      it 'split over 2 packages' do
        package1 = pack do |package|
          package.add line_item1, 1, :on_hand
        end
        package2 = pack do |package|
          package.add line_item2, 1, :on_hand
        end

        packages = [package1, package2]
        prioritizer = Prioritizer.new(order, packages)
        packages = prioritizer.prioritized_packages
        packages.size.should eq 2
      end

      it '1st has some, 2nd has remaining' do
        order.line_items[0].stub(:quantity => 5)
        package1 = pack do |package|
          package.add line_item1, 2, :on_hand
        end
        package2 = pack do |package|
          package.add line_item1, 5, :on_hand
        end

        packages = [package1, package2]
        prioritizer = Prioritizer.new(order, packages)
        packages = prioritizer.prioritized_packages
        packages.count.should eq 2
        packages[0].quantity.should eq 2
        packages[1].quantity.should eq 3
      end

      it '1st has backorder, 2nd has some' do
        order.line_items[0].stub(:quantity => 5)
        package1 = pack do |package|
          package.add line_item1, 5, :backordered
        end
        package2 = pack do |package|
          package.add line_item1, 2, :on_hand
        end

        packages = [package1, package2]
        prioritizer = Prioritizer.new(order, packages)
        packages = prioritizer.prioritized_packages

        packages[0].quantity(:backordered).should eq 3
        packages[1].quantity(:on_hand).should eq 2
      end

      it '1st has backorder, 2nd has all' do
        order.line_items[0].stub(:quantity => 5)
        package1 = pack do |package|
          package.add line_item1, 3, :backordered
          package.add line_item2, 1, :on_hand
        end
        package2 = pack do |package|
          package.add line_item1, 5, :on_hand
        end

        packages = [package1, package2]
        prioritizer = Prioritizer.new(order, packages)
        packages = prioritizer.prioritized_packages
        packages[0].quantity(:backordered).should eq 0
        packages[1].quantity(:on_hand).should eq 5
      end
    end
  end
end
