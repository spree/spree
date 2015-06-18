require 'spec_helper'

module Spree
  module Stock
    describe ContentItem, type: :model do
      let(:variant) { build(:variant, weight: 25.0) }
      subject { ContentItem.new(build(:inventory_unit, variant: variant)) }

      context "#volume" do
        it "calculate the total volume of the variant" do
          expect(subject.volume).to eq variant.volume * subject.quantity
        end
      end
    end
  end
end
