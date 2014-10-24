require 'spec_helper'

module Spree
  module Stock
    module Splitter
      describe Weight, :type => :model do
        let(:packer) { build(:stock_packer) }
        let(:variant) { build(:base_variant, :weight => 100) }
        let(:line_item) { build(:line_item, variant: variant) }

        subject { Weight.new(packer) }

        it 'splits and keeps splitting until all packages are underweight' do
          package = Package.new(packer.stock_location, packer.order)
          package.add line_item, 1
          package.add line_item, 1
          package.add line_item, 1
          package.add line_item, 1
          packages = subject.split([package])
          expect(packages.size).to eq 4
        end

        it 'handles packages that can not be reduced' do
          package = Package.new(packer.stock_location, packer.order)
          allow(variant).to receive_messages(:weight => 200)
          package.add line_item, 4
          package.add line_item, 4
          packages = subject.split([package])
          expect(packages.size).to eq 2
        end
      end
    end
  end
end
