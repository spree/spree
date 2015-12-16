require 'spec_helper'

describe Spree::PromotionRule, type: :model do
  class TestRule < Spree::PromotionRule
    def eligible?
      true
    end
  end

  describe '#eligible' do
    let(:promotable) { instance_double(Spree::Order) }

    it 'raises error' do
      expect { subject.eligible?(promotable) }.to raise_error(
        RuntimeError,
        'eligible? should be implemented in a sub-class of Spree::PromotionRule'
      )
    end
  end

  context 'validations' do
    let(:promotion) { create(:promotion) }

    it 'is unique on promotion' do
      TestRule.create!(promotion: promotion)

      expect(TestRule.new(promotion: promotion)).to_not be_valid
    end
  end
end
