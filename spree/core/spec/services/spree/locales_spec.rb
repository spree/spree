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

    it 'is accepted by I18n and Mobility even without translation files, falling back to English for messages' do
      I18n.with_locale(:yo) do
        Mobility.with_locale(:yo) { expect(I18n.t('spree.locale')).to eq('Locale') }
      end
    end

    it "includes every locale Spree ships translations for, so the setup wizard's suggestions are valid" do
      expect(Spree::SHIPPED_LOCALES.map(&:to_s) - subject).to eq([])
    end
  end

  describe '.unlisted' do
    it 'names the codes of a comma-separated list that are not listed, matching case exactly' do
      expect([described_class.unlisted('en,pt-br,xx'), described_class.unlisted(nil)]).to eq([%w[pt-br xx], []])
    end

    it 'ignores spaces and empty entries' do
      expect(described_class.unlisted('en, de,,fr ')).to eq([])
    end
  end

  describe '.listed' do
    it 'keeps a listed code and moves another to its listed language' do
      expect(%w[pt-BR en-IE zh].map { |code| described_class.listed(code) }).to eq(%w[pt-BR en zh-CN])
    end

    it 'finds a listed code written with an underscore or in another case' do
      expect(%w[en_US pt-br PT_BR].map { |code| described_class.listed(code) }).to eq(%w[en-US pt-BR pt-BR])
    end

    it 'gives nothing for a language Spree does not know, or a blank code' do
      expect([described_class.listed('xx-YY'), described_class.listed(nil)]).to eq([nil, nil])
    end
  end

  describe '.for_language' do
    it 'picks the language, or its first regional variant when only those are listed' do
      expect([described_class.for_language('de'), described_class.for_language('zh'), described_class.for_language('xx')]).to eq(['de', 'zh-CN', nil])
    end
  end
end
