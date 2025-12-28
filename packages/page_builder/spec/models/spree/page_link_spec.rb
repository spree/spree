require 'spec_helper'

RSpec.describe Spree::PageLink, type: :model do
  context 'when linkable is deleted' do
    describe 'Spree::Taxon' do
      it 'deletes the page link' do
        category = create(:taxon)
        page_link = create(:page_link, linkable: category)

        expect(Spree::PageLink.exists?(page_link.id)).to be true
        category.destroy
        expect(Spree::PageLink.exists?(page_link.id)).to be false
      end
    end

    describe 'Spree::Page' do
      it 'deletes the page link' do
        page = Spree::Page.first
        page_link = create(:page_link, linkable: page)

        expect(Spree::PageLink.exists?(page_link.id)).to be true
        page.destroy
        expect(Spree::PageLink.exists?(page_link.id)).to be false
      end
    end

    describe 'Spree::Product' do
      it 'deletes the page link' do
        product = create(:product)
        page_link = create(:page_link, linkable: product)

        expect(Spree::PageLink.exists?(page_link.id)).to be true
        product.destroy
        expect(Spree::PageLink.exists?(page_link.id)).to be false
      end
    end
  end

  describe '#formatted_url' do
    it 'returns the formatted url' do
      page_link = build(:page_link, url: 'https://www.google.com')
      expect(page_link.formatted_url).to eq('https://www.google.com')
    end

    context 'url without http' do
      it 'returns the formatted url' do
        page_link = build(:page_link, url: 'www.google.com')
        expect(page_link.formatted_url).to eq('http://www.google.com')
      end
    end

    context 'mailto links' do
      it 'returns the formatted url' do
        page_link = build(:page_link, url: 'mailto:test@example.com')
        expect(page_link.formatted_url).to eq('mailto:test@example.com')
      end
    end

    context 'url is blank' do
      it 'returns nil' do
        page_link = build(:page_link, url: nil)
        expect(page_link.formatted_url).to be_nil
      end
    end
  end
end
