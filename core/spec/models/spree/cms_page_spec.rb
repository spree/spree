require 'spec_helper'

describe Spree::CmsPage, type: :model do
  let!(:store_a) { create(:store) }
  let!(:store_b) { create(:store) }

  describe 'Spree::Cms::Pages::Homepage' do
    let(:homepage) { create(:cms_homepage, store: store_a) }

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

    it 'homepage is visable by default' do
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

    it 'feature_page is visable by default' do
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

    it 'standard_page is visable by default' do
      expect(standard_page.visible?).to be true
    end

    it 'standard_page is not in draft_mode by default' do
      expect(standard_page.draft_mode?).to be false
    end
  end

  describe 'by_store' do
    let!(:homepage_a) { create(:cms_homepage, store: store_a) }
    let!(:homepage_b) { create(:cms_homepage, store: store_b) }

    it 'returns homepage for the requested store' do
      expect(described_class.by_store(store_a)).to include(homepage_a)
      expect(described_class.by_store(store_a)).not_to include(homepage_b)
    end
  end

  describe 'by_locale' do
    let!(:homepage_en) { create(:cms_homepage, store: store_a, locale: 'en') }
    let!(:homepage_de) { create(:cms_homepage, store: store_a, locale: 'de') }

    it 'returns homepage for the requested locale' do
      expect(described_class.by_locale(:de)).to include(homepage_de)
      expect(described_class.by_locale(:de)).not_to include(homepage_en)
    end
  end

  describe 'by_slug' do
    let!(:standard_page_slug_a) { create(:cms_standard_page, store: store_a, title: 'Little Page') }
    let!(:standard_page_slug_b) { create(:cms_standard_page, store: store_a, title: 'Big Page') }

    it 'returns standard_page_slug_a for the requested locale' do
      expect(described_class.by_slug('little-page')).to include(standard_page_slug_a)
      expect(described_class.by_slug('not-little-page')).not_to include(standard_page_slug_a)
    end
  end

  describe 'linkable' do
    let!(:homepage_not_linkable) { create(:cms_homepage, store: store_a, title: 'homepage-a') }
    let!(:feature_page_linkable) { create(:cms_feature_page, title: 'This New Product', store: store_a) }
    let!(:standard_page_linkable) { create(:cms_standard_page, store: store_a, title: 'Big Page') }

    it 'returns standard_page_slug_a for the requested locale' do
      expect(described_class.linkable).to include(feature_page_linkable)
      expect(described_class.linkable).to include(standard_page_linkable)
      expect(described_class.linkable).not_to include(homepage_not_linkable)
    end
  end

  describe '#seo_title' do
    let!(:homepage_title) { create(:cms_homepage, store: store_a, title: 'This Is My Homepage Title') }

    it 'seo_title' do
      expect(homepage_title.seo_title).to eql(homepage_title.title)
    end
  end
end
