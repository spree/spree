require 'spec_helper'

module Spree
  module Stock
    describe Prioritizer, type: :model do
      let(:variant) { build(:variant, weight: 25.0) }
      let(:stock_location) { build(:stock_location) }
      let(:order) { build(:order) }

      def inventory_units
        @inventory_units ||= []
      end

      def build_inventory_unit
        build(:inventory_unit, variant: variant).tap do |unit|
          inventory_units << unit
        end
      end

      def pack
        package = Package.new(stock_location)
        yield(package) if block_given?
        package
      end

      describe 'deliverability' do
        let(:other_location) { build(:stock_location) }

        def deliverable_only(*deliverable_packages)
          estimator = instance_double(Estimator)
          allow(estimator).to receive(:deliverable?) { |package| deliverable_packages.include?(package) }
          estimator
        end

        it 'fills the units from an origin that can deliver rather than the first one offered' do
          2.times { build_inventory_unit }

          undeliverable = pack { |package| inventory_units.each { |unit| package.add unit } }
          deliverable = Package.new(other_location).tap do |package|
            inventory_units.each { |unit| package.add unit }
          end

          packages = Prioritizer.new([undeliverable, deliverable],
                                     estimator: deliverable_only(deliverable)).prioritized_packages

          expect(packages).to eq [deliverable]
          expect(packages.first.quantity).to eq 2
        end

        it 'keeps the order it was given between origins that can both deliver' do
          2.times { build_inventory_unit }

          first = pack { |package| package.add inventory_units.first }
          second = Package.new(other_location).tap { |package| package.add inventory_units.last }

          packages = Prioritizer.new([first, second],
                                     estimator: deliverable_only(first, second)).prioritized_packages

          expect(packages).to eq [first, second]
        end

        it 'leaves the order alone without an estimator to ask' do
          build_inventory_unit
          first = pack { |package| package.add inventory_units.first }
          second = Package.new(other_location).tap { |package| package.add inventory_units.first }

          expect(Prioritizer.new([first, second]).prioritized_packages).to eq [first]
        end
      end

      it 'keeps a single package' do
        package1 = pack do |package|
          package.add build_inventory_unit
          package.add build_inventory_unit
        end

        packages = [package1]
        prioritizer = Prioritizer.new(packages)
        packages = prioritizer.prioritized_packages
        expect(packages.size).to eq 1
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
        prioritizer = Prioritizer.new(packages)
        packages = prioritizer.prioritized_packages
        expect(packages.size).to eq 1
      end

      it 'split over 2 packages' do
        package1 = pack do |package|
          package.add build_inventory_unit
        end
        package2 = pack do |package|
          package.add build_inventory_unit
        end

        packages = [package1, package2]
        prioritizer = Prioritizer.new(packages)
        packages = prioritizer.prioritized_packages
        expect(packages.size).to eq 2
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
        prioritizer = Prioritizer.new(packages)
        packages = prioritizer.prioritized_packages
        expect(packages.count).to eq 2
        expect(packages[0].quantity).to eq 2
        expect(packages[1].quantity).to eq 3
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
        prioritizer = Prioritizer.new(packages)
        packages = prioritizer.prioritized_packages

        expect(packages[0].quantity(:backordered)).to eq 3
        expect(packages[1].quantity(:on_hand)).to eq 2
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
        prioritizer = Prioritizer.new(packages)
        packages = prioritizer.prioritized_packages
        expect(packages[0]).to eq package2
        expect(packages[1]).to be_nil
        expect(packages[0].quantity(:backordered)).to eq 0
        expect(packages[0].quantity(:on_hand)).to eq 5
      end
    end
  end
end
