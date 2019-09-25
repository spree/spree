require 'spec_helper'

describe 'JSON-LD hashes', type: :feature, inaccessible: true do
  include_context 'custom products'

  shared_examples 'it contains JSON-LD hash' do
    it 'contains JSON-LD hash' do
      expect(page).to have_selector('script[type="application/ld+json"]', visible: false)
    end
  end

  before do
    create(:store)
    visit spree.root_path
  end

  context 'home page' do
    it_behaves_like 'it contains JSON-LD hash'
  end

  context 'products page' do
    before { visit spree.products_path }

    it_behaves_like 'it contains JSON-LD hash'
  end

  context 'product page' do
    before { click_link 'Ruby on Rails Baseball Jersey' }

    it_behaves_like 'it contains JSON-LD hash'
  end

  context 'taxon page' do
    before { click_link 'Bags' }

    it_behaves_like 'it contains JSON-LD hash'
  end
end
