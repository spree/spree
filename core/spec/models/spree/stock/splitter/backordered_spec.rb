require 'spec_helper'

module Spree
  module Stock
    module Splitter
      describe Backordered, type: :model do
        subject(:result) do
          described_class.new(packer).split([package])
        end

        let(:packer) { build(:stock_packer) }
        let(:package) { Package.new(packer.stock_location) }

        before do
          package.add_multiple(build_stubbed_list(:inventory_unit, 4, :without_assoc))
          package.add_multiple(build_stubbed_list(:inventory_unit, 5, :without_assoc), :backordered)
        end

        it 'splits packages by status' do
          expect(result.count).to eq 2

          expect(result[0].quantity).to eq 4
          expect(result[0].on_hand.count).to eq 4
          expect(result[0].backordered.count).to eq 0

          expect(result[1].quantity).to eq 5
          expect(result[1].on_hand.count).to eq 0
          expect(result[1].backordered.count).to eq 5
        end
      end
    end
  end
end
