require 'spec_helper'

module Spree
  describe Promotions::PopulatePromotionBatch do
    describe "#call" do
      subject(:populate_promotion_batch) { described_class.new(batch_id, options).call }

      let(:batch_id) { double }
      let(:options) { {batch_size: 3} }
      let(:promotion_batch) { build(:promotion_batch) }
      let(:template_promotion_id) { double }

      before do
        allow(Spree::PromotionBatch)
          .to receive(:find)
          .and_return(promotion_batch)
        allow(promotion_batch)
          .to receive(:template_promotion_id)
          .and_return(template_promotion_id)
        allow(Spree::Promotions::DuplicatePromotionJob)
          .to receive(:perform_later)
          .with(options)
      end

      context "when PromotionBatch has a template assigned" do
        it "enqueues DuplicatePromotionJob jobs", sidekiq: :inline do
          expect(Spree::Promotions::DuplicatePromotionJob)
            .to receive(:perform_later)
            .at_least(options[:batch_size]).times
            .with(template_promotion_id: template_promotion_id, batch_id: batch_id, options: {})

          populate_promotion_batch
        end
      end

      context "when PromotionBatch hasn't a template assigned" do
        before do
          allow(promotion_batch)
            .to receive(:template_promotion_id)
            .and_return(nil)
        end

        it "raises an error" do
          expect { populate_promotion_batch }.to raise_error Spree::Promotions::PopulatePromotionBatch::TemplateNotFoundError
        end
      end
    end
  end
end
