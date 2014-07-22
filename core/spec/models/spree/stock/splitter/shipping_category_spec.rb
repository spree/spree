require 'spec_helper'

module Spree
  module Stock
    module Splitter
      describe ShippingCategory do

        let(:variant1) { build(:variant) }
        let(:variant2) { build(:variant) }
        let(:shipping_category_1) { create(:shipping_category, name: 'A') }
        let(:shipping_category_2) { create(:shipping_category, name: 'B') }

        def inventory_unit1
          build(:inventory_unit, variant: variant1).tap do |inventory_unit|
            inventory_unit.variant.product.shipping_category = shipping_category_1
          end
        end

        def inventory_unit2
          build(:inventory_unit, variant: variant2).tap do |inventory_unit|
            inventory_unit.variant.product.shipping_category = shipping_category_2
          end
        end

        let(:packer) { build(:stock_packer) }

        subject { ShippingCategory.new(packer) }

        it 'splits each package by shipping category' do
          package1 = Package.new(packer.stock_location)
          4.times { package1.add inventory_unit1 }
          8.times { package1.add inventory_unit2 }

          package2 = Package.new(packer.stock_location)
          6.times { package2.add inventory_unit1 }
          9.times { package2.add inventory_unit2, :backordered }

          packages = subject.split([package1, package2])
          packages[0].quantity.should eq 4
          packages[1].quantity.should eq 8
          packages[2].quantity.should eq 6
          packages[3].quantity.should eq 9
        end

      end
    end
  end
end
