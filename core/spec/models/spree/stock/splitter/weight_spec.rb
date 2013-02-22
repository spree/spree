require 'spec_helper'

module Spree
  module Stock
    module Splitter
      describe Weight do
        let(:packer) { build(:stock_packer) }
        let(:variant) { build(:base_variant, :weight => 100) }

        subject { Weight.new(packer) }

        it 'splits and keeps splitting until all packages are underweight' do
          package = Package.new(packer.stock_location, packer.order)
          package.add variant, 1
          package.add variant, 1
          package.add variant, 1
          package.add variant, 1
          packages = subject.split([package])
          packages.size.should eq 4
        end

        it 'handles packages that can not be reduced' do
          package = Package.new(packer.stock_location, packer.order)
          variant.stub(:weight => 200)
          package.add variant, 4
          package.add variant, 4
          packages = subject.split([package])
          packages.size.should eq 2
        end

      end
    end
  end
end

