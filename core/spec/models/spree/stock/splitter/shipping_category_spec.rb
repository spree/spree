require 'spec_helper'

module Spree
  module Stock
    module Splitter
      describe ShippingCategory do
        let(:variant1) {
          variant = build(:variant)
          variant.product.shipping_category = create(:shipping_category, name: 'A')
          variant
        }
        let(:variant2) {
          variant = build(:variant)
          variant.product.shipping_category = create(:shipping_category, name: 'B')
          variant
        }
        let(:packer) { build(:stock_packer) }

        subject { ShippingCategory.new(packer) }

        it 'splits each package by shipping category' do
          package1 = Package.new(packer.stock_location, packer.order)
          package1.add variant1, 4, :on_hand
          package1.add variant2, 8, :on_hand

          package2 = Package.new(packer.stock_location, packer.order)
          package2.add variant1, 6, :on_hand
          package2.add variant2, 9, :backordered

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
