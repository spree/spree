require 'spec_helper'

module Spree
  module Stock
    module Splitter
      describe Digital, type: :model do
        subject { described_class.new(packer) }

        let(:packer) { build(:stock_packer) }

        let(:digital_shipping_method) { create(:digital_shipping_method) }
        let(:product1) { create(:product, shipping_category: digital_shipping_method.shipping_categories.first) }
        let(:product2) { create(:product) }

        let(:item1) { create(:inventory_unit, variant: create(:variant, product: product1, digitals: [create(:digital)])) }
        let(:item2) { create(:inventory_unit, variant: create(:variant, product: product2)) }
        let(:item3) { create(:inventory_unit, variant: create(:variant, product: product2)) }
        let(:item4) { create(:inventory_unit, variant: create(:variant, product: product1, digitals: [create(:digital)])) }
        let(:item5) { create(:inventory_unit, variant: create(:variant, product: product1, digitals: [create(:digital)])) }

        it 'splits each package by product digital status' do
          package1 = Package.new(packer.stock_location)
          package1.add item1, :on_hand
          package1.add item2, :on_hand
          package1.add item3, :on_hand
          package1.add item4, :on_hand
          package1.add item5, :on_hand

          packages = subject.split([package1])

          expect(packages[0].quantity).to eq 3
          expect(packages[1].quantity).to eq 2
        end
      end
    end
  end
end
