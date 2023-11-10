require 'spec_helper'

describe Spree::PromotionBatch, type: :model do
  describe 'validations' do
    describe 'template_assignment' do
      let(:promotion) { create(:promotion) }
      let(:other_promotion) { create(:promotion) }
      let(:promotion_batch) { create(:promotion_batch, template_promotion: promotion) }

      before do
        promotion
        other_promotion
        promotion_batch
      end

      it 'should validate template_assignment on update' do
        expect { promotion_batch.update!(template_promotion: other_promotion) }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
