require 'spec_helper'

module Spree
  module Stock
    module Splitter
      describe FulfillmentType, type: :model do
        subject { described_class.new(packer) }

        let(:packer) { build(:stock_packer) }

        let(:digital_product) { create(:digital_product) }
        let(:physical_product) { create(:product) }

        let(:item1) { create(:inventory_unit, variant: create(:variant, product: digital_product, digitals: [create(:digital)])) }
        let(:item2) { create(:inventory_unit, variant: create(:variant, product: physical_product)) }
        let(:item3) { create(:inventory_unit, variant: create(:variant, product: physical_product)) }
        let(:item4) { create(:inventory_unit, variant: create(:variant, product: digital_product, digitals: [create(:digital)])) }

        it 'splits packages so fulfillment-type sets stay homogeneous' do
          package = Package.new(packer.stock_location)
          package.add item1, :on_hand
          package.add item2, :on_hand
          package.add item3, :on_hand
          package.add item4, :on_hand

          packages = subject.split([package])

          expect(packages.size).to eq(2)
          expect(packages.map { |p| p.fulfillment_types.sort }).to match_array([['digital'], ['shipping']])
          expect(packages.sum { |p| p.contents.size }).to eq(4)
        end

        it 'keeps a single package when every item shares the same types' do
          package = Package.new(packer.stock_location)
          package.add item2, :on_hand
          package.add item3, :on_hand

          packages = subject.split([package])

          expect(packages.size).to eq(1)
        end
      end
    end
  end
end
