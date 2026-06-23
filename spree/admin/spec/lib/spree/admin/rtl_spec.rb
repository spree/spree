require 'spec_helper'

describe Spree::Admin::Rtl do
  describe '.rtl_locale?' do
    it 'returns true for Arabic' do
      expect(described_class.rtl_locale?(:ar)).to be(true)
      expect(described_class.rtl_locale?('ar-SA')).to be(true)
    end

    it 'returns true for other RTL languages' do
      expect(described_class.rtl_locale?(:he)).to be(true)
      expect(described_class.rtl_locale?(:fa)).to be(true)
    end

    it 'returns false for LTR languages' do
      expect(described_class.rtl_locale?(:en)).to be(false)
      expect(described_class.rtl_locale?(:de)).to be(false)
    end
  end

  describe '.html_dir' do
    it 'returns rtl for RTL locales' do
      expect(described_class.html_dir(:ar)).to eq('rtl')
    end

    it 'returns ltr for LTR locales' do
      expect(described_class.html_dir(:en)).to eq('ltr')
    end
  end
end
