require 'spec_helper'

RSpec.describe 'Home Page', type: :feature, js: true do
  let(:store) { Spree::Store.default }

  describe 'visiting the home page' do
    before do
      visit '/'
    end

    it 'loads successfully' do
      expect(page).to have_content(store.name)
    end
  end
end
