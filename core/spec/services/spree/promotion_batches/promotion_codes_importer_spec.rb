require 'spec_helper'

module Spree
  describe PromotionBatches::PromotionCodesImporter do
    subject(:import_promo_codes) do
      described_class.new(file: file, promotion_batch_id: promotion_batch.id).call
    end

    let(:promotion_batch) { build(:promotion_batch) }
    let(:code1) { 'cf14cec8' }
    let(:code2) { '4b2ff1a7' }
    let(:template_promotion_id) { double }
    let(:batch_id) { double }
    let(:content) do
      <<~CSV
        #{code1}
        #{code2}
      CSV
    end
    let(:file) { double }
    let(:content_type) { 'text/csv' }

    before do
      allow(file)
        .to receive(:content_type)
        .and_return(content_type)
      allow(file)
        .to receive(:read)
        .and_return(content)
      allow(Spree::PromotionBatch)
        .to receive(:find)
        .and_return(promotion_batch)
      allow(promotion_batch)
        .to receive(:template_promotion_id)
        .and_return(template_promotion_id)
      allow(promotion_batch)
        .to receive(:id)
        .and_return(batch_id)
    end

    context "when file is correct" do
      it "enqueues DuplicatePromotionJob jobs", sidekiq: :inline do
        expect(Spree::Promotions::DuplicatePromotionJob)
          .to receive(:perform_later)
          .with(template_promotion_id: template_promotion_id, batch_id: batch_id, code: code1)
        expect(Spree::Promotions::DuplicatePromotionJob)
          .to receive(:perform_later)
          .with(template_promotion_id: template_promotion_id, batch_id: batch_id, code: code2)

        import_promo_codes
      end
    end

    context "when file has wrong content type" do
      let(:content_type) { 'unallowable_type' }

      it "raises an error" do
        expect { import_promo_codes }.to raise_error Spree::PromotionBatches::PromotionCodesImporter::Error
      end
    end

    context "when file is empty" do
      let(:content) { "" }

      it "raises an error" do
        expect { import_promo_codes }.to raise_error Spree::PromotionBatches::PromotionCodesImporter::Error
      end
    end

    context "when there's no file" do
      let(:file) { nil }

      it "raises an error" do
        expect { import_promo_codes }.to raise_error Spree::PromotionBatches::PromotionCodesImporter::Error
      end
    end
  end
end
