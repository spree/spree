require 'spec_helper'

module Spree
  describe PromotionBatches::GenerateCode do
    subject { described_class.new.call(random_characters: random_characters, prefix: prefix, suffix: suffix) }

    let(:random_characters) { 4 }
    let(:prefix) { nil }
    let(:suffix) { nil }

    context 'when no prefix or suffix is set' do
      it 'returns randomly generated code in uppercase' do
        expect(subject).to match('^[A-Z0-9]*$')
      end
      it 'returns randomly generated code with correct length' do
        expect(subject.length).to eq(4)
      end
    end

    context 'when a prefix is set' do
      let(:prefix) { 'MYCAMPAIGN_' }

      it 'returns prefix and randomly generated code' do
        expect(subject).to match('^MYCAMPAIGN_[A-Z0-9]{4}$')
      end
    end

    context 'when a suffix is set' do
      let(:suffix) { '_RETAIL' }

      it 'returns randomly generated code with suffix' do
        expect(subject).to match('^[A-Z0-9]{4}_RETAIL$')
      end
    end

    context 'when both a prefix and a suffix is set' do
      let(:prefix) { 'TESTCAMPAIGN_' }
      let(:suffix) { '_ONLINE' }

      it 'returns randomly generated code with prefix and suffix' do
        expect(subject).to match('^TESTCAMPAIGN_[A-Z0-9]{4}_ONLINE$')
      end
    end
  end
end
