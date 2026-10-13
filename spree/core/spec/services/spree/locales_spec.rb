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

    it "includes every locale Spree ships translations for, so the setup wizard's suggestions are valid" do
      expect(Spree::SHIPPED_LOCALES.map(&:to_s) - subject).to eq([])
    end
  end

  describe '.unlisted' do
    it 'names the codes of a comma-separated list that are not listed, matching case exactly' do
      expect([described_class.unlisted('en,pt-br,xx'), described_class.unlisted(nil)]).to eq([%w[pt-br xx], []])
    end
  end

  describe '.for_language' do
    it 'picks the language, or its first regional variant when only those are listed' do
      expect([described_class.for_language('de'), described_class.for_language('zh'), described_class.for_language('xx')]).to eq(['de', 'zh-CN', nil])
    end
  end
end
