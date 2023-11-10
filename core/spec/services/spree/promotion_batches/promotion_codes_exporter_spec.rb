require 'spec_helper'

module Spree
  describe PromotionBatches::PromotionCodesExporter do
    subject(:input) do
      described_class.new(params).call
    end

    let(:promotion_batch) { create(:promotion_batch) }
    let(:promotion) { create(:promotion, :with_unique_code, promotion_batch_id: promotion_batch.id  ) }
    let(:promotion2) { create(:promotion, :with_unique_code, promotion_batch_id: promotion_batch.id  ) }
    let(:params) { { id: promotion_batch.id } }

    let(:expected_codes_csv) do
      <<~CSV
        #{promotion.code}
        #{promotion2.code}
      CSV
    end

    before do
      promotion
      promotion2
    end

    it "generates correct csv file" do
      expect(input).to eq expected_codes_csv
    end
  end
end
