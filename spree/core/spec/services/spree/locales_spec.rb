require 'spec_helper'

RSpec.describe Spree::Locales do
  describe 'ALL' do
    subject { described_class::ALL }

    it { is_expected.to be_frozen }

    it 'uses BCP-47 casing for regional variants (lowercase language, uppercase region)' do
      variants = subject.select { |code| code.include?('-') }
      expect(variants).to all(match(/\A[a-z]{2,3}-[A-Z0-9]+\z/))
    end

    it 'includes commerce-critical regional variants' do
      expect(subject).to include('en-GB', 'pt-BR', 'pt-PT', 'es-MX', 'fr-CA', 'zh-CN', 'zh-TW')
    end

    it 'has no duplicate codes' do
      expect(subject).to eq(subject.uniq)
    end
  end
end
