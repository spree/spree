require 'spec_helper'

module Spree
  describe PromotionBatches::BatchCodeGenerator do
    subject(:generate_batch_code) { described_class.build(batch_id, options) }

    let(:promotion) { build(:promotion, code: existing_code) }
    let(:promotion_batch) { build(:promotion_batch) }
    let(:code_generator) { instance_double(Promotions::CodeGenerator) }
    let(:existing_code) { "existing_code" }
    let(:new_code) { "new_code" }
    let(:options) { {key: 'value'} }
    let(:batch_id) { double }


    before do
      allow(promotion_batch)
        .to receive(:id)
        .and_return(batch_id)
      allow(Spree::PromotionBatch)
        .to receive(:find)
        .and_return(promotion_batch)
      allow(promotion_batch)
        .to receive(:promotions)
        .and_return([promotion])
      allow(Promotions::CodeGenerator)
        .to receive(:new)
        .and_return(code_generator)
      allow(code_generator)
        .to receive(:build)
        .and_return(existing_code, new_code)
    end

    it 'returns new code' do
      expect(subject).to eq(new_code)
    end
  end
end
