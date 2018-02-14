require 'spec_helper'

module Spree
  module Stock
    module Splitter
      describe Base, type: :model do
        let(:splitter1) { described_class.new(packer) }
        let(:splitter2) { described_class.new(packer, splitter1) }

        let(:packer) { build(:stock_packer) }

        let(:packages) { [] }

        describe 'continues to splitter chain' do
          it { expect(splitter1).to receive(:split).with(packages) }

          after { splitter2.split(packages) }
        end
      end
    end
  end
end
