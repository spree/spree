require 'spec_helper'

describe Spree::CmsPage, type: :model do
  let!(:store_a) { create(:store) }
  let!(:store_b) { create(:store) }

  it 'validates presence of title' do
    expect(described_class.new(title: nil, store: store_a, locale: :en)).not_to be_valid
  end

  it 'validates presence of store' do
    expect(described_class.new(title: 'Got Name', store: nil, locale: :en)).not_to be_valid
  end

  it 'validates presence of locale' do
    expect(described_class.new(title: 'Got Name', store: store_a, locale: nil)).not_to be_valid
  end

  describe 'validates uniqueness of homepage by locale' do
    let!(:homepage) { create(:cms_homepage, store: store_a, locale: 'en') }

    it 'valid' do
      expect(described_class.new(title: 'Got Name', store: store_a, locale: 'en', type: 'Spree::Cms::Pages::Homepage')).not_to be_valid
    end
  end

  describe 'validates uniqueness of slug' do
    context 'valid' do
      let!(:page) { create(:cms_standard_page, store: store_a, slug: 'got-name', locale: 'en') }

      it 'valid' do
        expect(described_class.new(title: 'Another Name', store: store_a, locale: 'en', type: 'Spree::Cms::Pages::StandardPage')).to be_valid
      end

      it 'omits previously deleted page' do
        expect { page.destroy }.to change(page, :deleted_at).from(nil).to(Time)
        expect(described_class.new(title: 'Got Name', store: store_a, slug: 'got-name', locale: 'en', type: 'Spree::Cms::Pages::StandardPage')).to be_valid
      end
    end

    context 'invalid' do
      let!(:page) { create(:cms_standard_page, store: store_a, slug: 'got-name', locale: 'en') }

      it 'invalid' do
        expect(described_class.new(title: 'Got Name', store: store_a, slug: 'got-name', locale: 'en', type: 'Spree::Cms::Pages::StandardPage')).not_to be_valid
      end
    end
  end

  describe 'Spree::Cms::Pages::Homepage' do
    let(:homepage) { create(:cms_homepage, store: store_a, locale: 'en') }

    it 'has a type of Spree::Cms::Pages::Homepage' do
      expect(homepage.type).to eq('Spree::Cms::Pages::Homepage')
    end

    it 'has a slug with nil value' do
      expect(homepage.slug).to be nil
    end

    it 'returns true for a homepage?' do
      expect(homepage.homepage?).to be true
    end

    it 'returns true for sections?' do
      expect(described_class.find_by(id: homepage.id).sections?).to be true
    end

    it 'homepage is visible by default' do
      expect(homepage.visible?).to be true
    end

    it 'homepage is not in draft_mode by default' do
      expect(homepage.draft_mode?).to be false
    end
  end

  describe 'Spree::Cms::Pages::FeaturePage' do
    let(:feature_page) { create(:cms_feature_page, title: 'This New Product', store: store_a) }

    it 'has a type of Spree::Cms::Pages::FeaturePage' do
      expect(feature_page.type).to eq('Spree::Cms::Pages::FeaturePage')
    end

    it 'has a slug that is the title parameterized' do
      expect(feature_page.slug).to eql('this-new-product')
    end

    it 'returns false for homepage?' do
      expect(feature_page.homepage?).to be false
    end

    it 'returns true for sections?' do
      expect(described_class.find_by(id: feature_page.id).sections?).to be true
    end

    it 'feature_page is visible by default' do
      expect(feature_page.visible?).to be true
    end

    it 'feature_page is not in draft_mode by default' do
      expect(feature_page.draft_mode?).to be false
    end
  end

  describe 'Spree::Cms::Pages::StandardPage' do
    let(:standard_page) { create(:cms_standard_page, title: 'About Us', store: store_a) }

    it 'has a type of Spree::Cms::Pages::FeaturePage' do
      expect(standard_page.type).to eq('Spree::Cms::Pages::StandardPage')
    end

    it 'has a slug that is the title parameterized' do
      expect(standard_page.slug).to eql('about-us')
    end

    it 'returns false for homepage?' do
      expect(standard_page.homepage?).to be false
    end

    it 'returns true for sections?' do
      expect(described_class.find_by(id: standard_page.id).sections?).to be false
    end

    it 'standard_page is visible by default' do
      expect(standard_page.visible?).to be true
    end

    it 'standard_page is not in draft_mode by default' do
      expect(standard_page.draft_mode?).to be false
    end
  end

  describe '.by_locale' do
    let!(:homepage_en) { create(:cms_homepage, store: store_a, locale: 'en') }
    let!(:homepage_de) { create(:cms_homepage, store: store_a, locale: 'de') }

    it 'returns homepage for the requested locale' do
      result_de = described_class.find(homepage_de.id)

      expect(described_class.by_locale(:de)).to eq([result_de])
    end
  end

  describe '.by_slug' do
    let!(:standard_page_slug_a) { create(:cms_standard_page, store: store_a, title: 'Little Page') }
    let!(:standard_page_slug_b) { create(:cms_standard_page, store: store_a, title: 'Big Page') }

    it 'returns standard_page_slug_a for the requested locale' do
      result_slug_a = described_class.find(standard_page_slug_a.id)

      expect(described_class.by_slug('little-page')).to eq([result_slug_a])
    end
  end

  describe '#seo_title' do
    let!(:homepage_title) { create(:cms_homepage, store: store_a, title: 'This Is My Homepage Title') }

    it 'seo_title' do
      expect(homepage_title.seo_title).to eql(homepage_title.title)
    end
  end
end
