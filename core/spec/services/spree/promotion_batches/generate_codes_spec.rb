require 'spec_helper'

module Spree
  describe PromotionBatches::GenerateCodes do
    subject { described_class.new(generate_code: generate_code_double).call(amount: 3, random_characters: 3, prefix: 'XXX', suffix: 'ZZZ') }

    let(:generate_code_double) { instance_double(Spree::PromotionBatches::GenerateCode) }

    context 'when generator returns unique codes' do
      before do
        allow(generate_code_double).to receive(:call).with(random_characters: 3, prefix: 'XXX', suffix: 'ZZZ')
                                                     .and_return('XXX_AAA_ZZZ', 'XXX_BBB_ZZZ', 'XXX_CCC_ZZZ')
      end

      it 'returns generated codes' do
        expect(subject).to eq(['XXX_AAA_ZZZ', 'XXX_BBB_ZZZ', 'XXX_CCC_ZZZ'])
      end
    end

    context 'when generator returns duplicate codes' do
      before do
        allow(generate_code_double).to receive(:call).with(random_characters: 3, prefix: 'XXX', suffix: 'ZZZ')
                                                     .and_return('XXX_AAA_ZZZ', 'XXX_BBB_ZZZ', 'XXX_AAA_ZZZ', 'XXX_CCC_ZZZ')
      end

      it 'skips duplicate codes' do
        expect(subject).to eq(['XXX_AAA_ZZZ', 'XXX_BBB_ZZZ', 'XXX_CCC_ZZZ'])
      end
    end

    context 'when generator returns duplicate codes more than three times in a row' do
      before do
        allow(generate_code_double).to receive(:call).with(random_characters: 3, prefix: 'XXX', suffix: 'ZZZ')
                                                     .and_return('XXX_BBB_ZZZ', 'XXX_AAA_ZZZ', 'XXX_AAA_ZZZ', 'XXX_AAA_ZZZ', 'XXX_AAA_ZZZ', 'XXX_AAA_ZZZ')
      end

      it 'returns an error' do
        expect { subject }.to raise_error(Spree::PromotionBatches::GenerateCodes::GenerateFailedError)
      end
    end
  end
end
