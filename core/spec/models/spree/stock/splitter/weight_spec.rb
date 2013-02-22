require 'spec_helper'

module Spree
  module Stock
    module Splitter
      describe Weight do
        let(:packer) { build(:stock_packer) }
        let(:variant) { build(:base_variant, :weight => 100) }

        subject { Weight.new(packer) }

        it 'splits package by weight' do
          package = Package.new(packer.stock_location, packer.order)
          package.add variant, 1
          package.add variant, 1
          packages = subject.split([package])
          packages.size.should eq 2
        end

        pending 'handles packages that can not be reduced'

      end
    end
  end
end
