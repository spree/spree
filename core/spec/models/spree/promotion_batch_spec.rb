require 'spec_helper'

describe Spree::PromotionBatch, type: :model do
  describe '#save' do
    let(:template_promotion) { create(:promotion) }
    let(:promotion_batch) { build(:promotion_batch, template_promotion: template_promotion, codes: codes) }

    subject { promotion_batch.save }

    context 'when there are no codes provided' do
      let(:codes) { [] }

      it 'fails validation' do
        subject
        expect(promotion_batch.errors[:codes]).to_not be_empty
        expect(promotion_batch.persisted?).to eq(false)
      end
    end

    context 'when codes are provided' do
      let(:codes) { ['TEST', 'TEST2'] }

      it 'passes validation' do
        subject
        expect(promotion_batch.errors[:codes]).to be_empty
        expect(promotion_batch.persisted?).to eq(true)
      end
    end
  end
end
