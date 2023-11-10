require 'spec_helper'

module Spree
  describe Promotions::HandleDescendantPromotionJob do
    describe "#perform" do
      let(:template_promotion) { build(:promotion) }
      let(:descendant_promotion) { build(:promotion) }
      let(:batch) { instance_double(Spree::PromotionBatch, id: 123) }
      let(:duplicator) { instance_double(Spree::PromotionHandler::PromotionBatchUpdateHandler) }

      before do
        allow(Spree::Promotion)
          .to receive(:find)
          .and_return(template_promotion, descendant_promotion)
      end

      subject(:execute_job) do
        described_class.new.perform(
          template_promotion_id: template_promotion.id,
          descendant_promotion_id: descendant_promotion.id,
          promotion_batch_id: batch.id
        )
      end

      it "sends #duplicate to the duplicator service" do
        expect(Spree::PromotionHandler::PromotionBatchUpdateHandler)
          .to receive(:new)
          .with(template_promotion, batch.id, descendant_promotion)
          .and_return(duplicator)
        expect(duplicator)
          .to receive(:duplicate)

        execute_job
      end
    end
  end
end
