require 'spec_helper'

module Spree
  module Stock
    describe ContentItem, type: :model do
      let(:variant) { build(:variant, weight: 25.0) }
      subject { ContentItem.new(build(:inventory_unit, variant: variant)) }

      describe 'Delegations' do
        it { is_expected.to delegate_method(:line_item).to(:inventory_unit) }
        it { is_expected.to delegate_method(:variant).to(:inventory_unit) }
        it { is_expected.to delegate_method(:dimension).to(:variant).with_prefix }
        it { is_expected.to delegate_method(:price).to(:variant) }
        it { is_expected.to delegate_method(:volume).to(:variant).with_prefix }
        it { is_expected.to delegate_method(:weight).to(:variant).with_prefix }
      end

      context "#volume" do
        it "calculate the total volume of the variant" do
          expect(subject.volume).to eq variant.volume * subject.quantity
        end
      end

      context "#dimension" do
        it "calculate the total dimension of the variant" do
          expect(subject.dimension).to eq variant.dimension * subject.quantity
        end
      end
    end
  end
end
