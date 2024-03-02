require 'spec_helper'

module Spree
  describe PromotionBatches::GenerateCode do
    subject { described_class.new(random: random_double).call(random_characters: random_characters, prefix: prefix, suffix: suffix) }

    let(:random_double) { double }
    let(:random_characters) { 4 }
    let(:prefix) { nil }
    let(:suffix) { nil }

    before do
      allow(random_double).to receive(:hex).with(random_characters).and_return('CODE')
    end

    context 'when no prefix or suffix is set' do
      it 'returns randomly generated code' do
        expect(subject).to eq('CODE')
      end
    end

    context 'when a prefix is set' do
      let(:prefix) { 'MYCAMPAIGN_' }

      it 'returns prefix and randomly generated code' do
        expect(subject).to eq('MYCAMPAIGN_CODE')
      end
    end

    context 'when a suffix is set' do
      let(:suffix) { '_RETAIL' }

      it 'returns randomly generated code with suffix' do
        expect(subject).to eq('CODE_RETAIL')
      end
    end

    context 'when both a prefix and a suffix is set' do
      let(:prefix) { 'TESTCAMPAIGN_' }
      let(:suffix) { '_ONLINE' }

      it 'returns randomly generated code with prefix and suffix' do
        expect(subject).to eq('TESTCAMPAIGN_CODE_ONLINE')
      end
    end
  end
end
