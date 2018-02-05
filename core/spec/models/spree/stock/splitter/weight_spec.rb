require 'spec_helper'

module Spree
  module Stock
    module Splitter
      describe Weight, type: :model do
        subject(:result) do
          described_class.new(packer).split(packages)
        end

        let(:packer) { build(:stock_packer) }
        let(:packages) { [package] }
        let(:package) { Package.new(packer.stock_location) }

        let(:heavy_variant) { build_stubbed(:base_variant, weight: 100) }
        let(:variant) { build_stubbed(:base_variant, weight: 49) }

        context 'with packages that can be reduced' do
          before do
            2.times { package.add(build_stubbed(:inventory_unit, :without_assoc, variant: heavy_variant)) }
            4.times { package.add(build_stubbed(:inventory_unit, :without_assoc, variant: variant)) }
            2.times { package.add(build_stubbed(:inventory_unit, :without_assoc, variant: heavy_variant)) }
          end

          it 'splits and keeps splitting until all packages are underweight' do
            expect(result.size).to eq 4

            result.each do |pack|
              expect(pack.weight).to be <= described_class.threshold
            end
          end
        end

        context 'with packages that can not be reduced' do
          let(:variant) { build_stubbed(:base_variant, weight: 200) }

          before do
            2.times { package.add(build_stubbed(:inventory_unit, :without_assoc, variant: variant)) }
          end

          it 'handles packages that can not be reduced' do
            # formula: (2*200) / 150
            expect(result.size).to eq 2
          end
        end

        xcontext 'with multiple packages' do
          let(:packages) { [package, package1] }
          let(:package1) { Package.new(packer.stock_location) }

          before do
            2.times { package.add(build_stubbed(:inventory_unit, :without_assoc, variant: heavy_variant)) }
            4.times { package.add(build_stubbed(:inventory_unit, :without_assoc, variant: variant)) }

            2.times { package1.add(build_stubbed(:inventory_unit, :without_assoc, variant: variant)) }
            4.times { package1.add(build_stubbed(:inventory_unit, :without_assoc, variant: heavy_variant)) }
          end

          it 'splits and keeps splitting until all packages are underweight' do
            # formula: (2*100 + 4*49 + 2*49 + 4*100) / 150
            expect(result.size).to eq 6
          end
        end
      end
    end
  end
end
