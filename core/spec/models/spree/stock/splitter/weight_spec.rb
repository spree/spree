require 'spec_helper'

module Spree
  module Stock
    module Splitter
      describe Weight, type: :model do
        let(:packer) { build(:stock_packer) }
        let(:heavy_variant) { build(:base_variant, weight: 100) }
        let(:variant) { build(:base_variant, weight: 49) }

        subject { Weight.new(packer) }

        it 'splits and keeps splitting until all packages are underweight' do
          package = Package.new(packer.stock_location)
          2.times { package.add build(:inventory_unit, variant: heavy_variant) }
          4.times { package.add build(:inventory_unit, variant: variant) }
          2.times { package.add build(:inventory_unit, variant: heavy_variant) }
          packages = subject.split([package])
          expect(packages.size).to eq 4
        end

        it 'handles packages that can not be reduced' do
          package = Package.new(packer.stock_location)
          allow(variant).to receive_messages(weight: 200)
          2.times { package.add build(:inventory_unit, variant: variant) }
          packages = subject.split([package])
          expect(packages.size).to eq 2
        end
      end
    end
  end
end
