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

  describe '.known?' do
    it 'accepts plain language codes' do
      expect(described_class.known?('en')).to be(true)
      expect(described_class.known?('de')).to be(true)
    end

    it 'accepts regional variants, including ones absent from ALL' do
      expect(described_class.known?('pt-BR')).to be(true)
      expect(described_class.known?('en-US')).to be(true)
      expect(described_class.known?('es-ES')).to be(true)
    end

    it 'rejects arbitrary strings' do
      expect(described_class.known?('rubbish')).to be(false)
      expect(described_class.known?('not a locale')).to be(false)
      expect(described_class.known?('../../etc/passwd')).to be(false)
    end

    it 'rejects a code whose base language does not exist' do
      expect(described_class.known?('xx')).to be(false)
      expect(described_class.known?('zz-ZZ')).to be(false)
    end

    it 'rejects blank input' do
      expect(described_class.known?(nil)).to be(false)
      expect(described_class.known?('')).to be(false)
    end
  end
end
