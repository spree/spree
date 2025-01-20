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
end
