require 'spec_helper'

module Spree
  module Stock
    describe ContentItem, type: :model do
      subject { ContentItem.new(build(:inventory_unit, variant: variant)) }

      let(:variant) { build(:variant, weight: 25.0) }

      context '#volume' do
        it 'calculate the total volume of the variant' do
          expect(subject.volume).to eq variant.volume * subject.quantity
        end
      end

      context '#dimension' do
        it 'calculate the total dimension of the variant' do
          expect(subject.dimension).to eq variant.dimension * subject.quantity
        end
      end
    end
  end
end
