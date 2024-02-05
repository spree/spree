require 'spec_helper'

module Spree
  describe PromotionBatches::Export do
    let(:exporter) { described_class.new }

    subject { exporter.call(promotion_batch: promotion_batch )}

    let(:promotion_batch) { create(:promotion_batch, codes: ['CODE1', 'CODE2'], promotions: [promotion1, promotion2]) }
    let(:promotion1) { create(:promotion, code: 'CODE1') }
    let(:promotion2) { create(:promotion, code: 'CODE2') }

    let(:expected_codes_csv) do
      <<~CSV
        #{promotion1.code}
        #{promotion2.code}
      CSV
    end

    it 'generates correct csv file' do
      expect(subject).to eq(expected_codes_csv)
    end
  end
end
