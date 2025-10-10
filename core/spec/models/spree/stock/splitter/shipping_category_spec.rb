require 'spec_helper'

module Spree
  module Stock
    module Splitter
      describe ShippingCategory, type: :model do
        subject(:result) do
          described_class.new(packer).split(packages)
        end

        let(:packer) { build(:stock_packer) }

        let(:packages) { [package1, package2] }
        let(:package1) { Spree::Stock::Package.new(packer.stock_location) }
        let(:package2) { Spree::Stock::Package.new(packer.stock_location) }

        let(:variant1) { build_stubbed(:variant, product: product1) }
        let(:product1) { build_stubbed(:product, shipping_category: shipping_category_1) }
        let(:variant2) { build_stubbed(:variant, product: product2) }
        let(:product2) { build_stubbed(:product, shipping_category: shipping_category_2) }

        let(:shipping_category_1) { build_stubbed(:shipping_category, name: 'A') }
        let(:shipping_category_2) { build_stubbed(:shipping_category, name: 'B') }

        before do
          package1.add_multiple(build_stubbed_list(:inventory_unit, 4, :without_assoc, variant: variant1))
          package1.add_multiple(build_stubbed_list(:inventory_unit, 8, :without_assoc, variant: variant2))

          package2.add_multiple(build_stubbed_list(:inventory_unit, 6, :without_assoc, variant: variant1))
          package2.add_multiple(build_stubbed_list(:inventory_unit, 9, :without_assoc, variant: variant2), :backordered)
        end

        it 'splits each package by shipping category' do
          expect(result[0].quantity).to eq 4
          expect(result[1].quantity).to eq 8
          expect(result[2].quantity).to eq 6
          expect(result[3].quantity).to eq 9
        end
      end
    end
  end
end
