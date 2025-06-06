require 'spec_helper'

RSpec.describe 'Search results page', type: :feature, js: true, job: true do
  context 'with query' do
    before do
      visit spree.search_path(q: 'Test')
    end

    it 'displays search results page' do
      expect(page).to have_current_path(spree.search_path(q: 'Test'))
    end
  end

  context 'without query' do
    before do
      visit spree.search_path
    end

    it 'redirects to collection page' do
      expect(page).to have_current_path(spree.search_path)
    end
  end
end
