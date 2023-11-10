require 'spec_helper'

module Spree
  describe PromotionBatches::Destroy do
    subject { described_class.call(promotion_batch: promotion_batch) }

    let(:promotion_batch) { create(:promotion_batch) }
    let(:promotion) { create(:promotion, promotion_batch_id: promotion_batch.id  ) }
    let(:promotion2) { create(:promotion, promotion_batch_id: promotion_batch.id  ) }

    before do
      promotion_batch
      promotion
      promotion2
    end

    it 'destroys the promotion batch with its promotions' do
      subject
      expect(Spree::Promotion.all).not_to include(promotion, promotion2)
      expect(Spree::PromotionBatch.all).not_to include(promotion_batch)
    end
  end
end
