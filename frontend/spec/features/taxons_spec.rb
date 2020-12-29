require 'spec_helper'

describe 'viewing products', type: :feature, inaccessible: true do
  let!(:taxonomy) { create(:taxonomy, name: 'Category') }
  let!(:super_clothing) { taxonomy.root.children.create(name: 'Super Clothing') }
  let!(:t_shirts) { super_clothing.children.create(name: 'T-Shirts') }
  let(:metas) { { meta_description: 'Brand new Ruby on Rails TShirts', meta_title: 'Ruby On Rails TShirt', meta_keywords: 'ror, tshirt, ruby' } }
  let(:store_name) { ((first_store = Spree::Store.first) && first_store.name).to_s }

  before do
    t_shirts.children.create(name: 'XXL') # xxl

    product = create(:product, name: 'Superman T-Shirt')
    product.taxons << t_shirts
  end

  # Regression test for #1796
  it "can see a taxon's products, even if that taxon has child taxons" do
    visit '/t/category/super-clothing/t-shirts'
    expect(page).to have_content('Superman T-Shirt')
  end

  it 'can visit root taxon' do
    visit '/t/category'
    expect(page).to have_content('Category')
  end

  it 'does not show nested taxons with a search' do
    visit '/products?keywords=shirt'

    expect(page).to have_content('Superman T-Shirt')
    expect(page).not_to have_selector("div[data-hook='taxon_children']")
  end

  describe 'breadcrumbs' do
    before do
      visit '/t/category/super-clothing/t-shirts'
    end

    it 'renders breadcrumbs' do
      expect(page.find('#breadcrumbs')).to have_link('T-Shirts')
    end
  end

  describe 'meta tags and title' do
    it 'displays metas' do
      t_shirts.update metas
      visit '/t/category/super-clothing/t-shirts'
      expect(page).to have_meta(:description, 'Brand new Ruby on Rails TShirts')
      expect(page).to have_meta(:keywords, 'ror, tshirt, ruby')
    end

    it 'display title if set' do
      t_shirts.update metas
      visit '/t/category/super-clothing/t-shirts'
      expect(page).to have_title('Ruby On Rails TShirt')
    end

    it 'displays title from taxon root and taxon name' do
      visit '/t/category/super-clothing/t-shirts'
      expect(page).to have_title('T-Shirts - ' + store_name)
    end

    # Regression test for #2814
    it "doesn't use meta_title as heading on page" do
      t_shirts.update metas
      visit '/t/category/super-clothing/t-shirts'

      within('.taxon-title') do
        expect(page).to have_content(t_shirts.name)
      end
    end

    it 'uses taxon name in title when meta_title set to empty string' do
      t_shirts.update meta_title: ''
      visit '/t/category/super-clothing/t-shirts'
      expect(page).to have_title('T-Shirts - ' + store_name)
    end
  end

  context 'taxon pages' do
    include_context 'custom products'

    it 'is able to visit brand Ruby on Rails' do
      visit '/t/brands/ruby-on-rails'

      expect(page).to have_css('.product-component-name').exactly(7).times

      tmp = page.all('.product-component-name').map(&:text).flatten.compact
      array = ['Ruby on Rails Bag',
               'Ruby on Rails Baseball Jersey',
               'Ruby on Rails Jr. Spaghetti',
               'Ruby on Rails Mug',
               'Ruby on Rails Ringer T-Shirt',
               'Ruby on Rails Stein',
               'Ruby on Rails Tote']
      expect(tmp.sort!).to eq(array)
    end

    it 'is able to visit brand Ruby' do
      visit '/t/brands/ruby'

      expect(page).to have_css('.product-component-name').once

      tmp = page.all('.product-component-name').map(&:text).flatten.compact
      expect(tmp.sort!).to eq(['Ruby Baseball Jersey'])
    end

    it 'is able to visit brand Apache' do
      visit '/t/brands/apache'

      expect(page).to have_css('.product-component-name').once
      tmp = page.all('.product-component-name').map(&:text).flatten.compact
      expect(tmp.sort!).to eq(['Apache Baseball Jersey'])
    end

    it 'is able to visit category Clothing' do
      visit '/t/categories/clothing'

      expect(page).to have_css('.product-component-name').exactly(5).times
      tmp = page.all('.product-component-name').map(&:text).flatten.compact
      expect(tmp.sort!).to eq(['Apache Baseball Jersey',
                               'Ruby Baseball Jersey',
                               'Ruby on Rails Baseball Jersey',
                               'Ruby on Rails Jr. Spaghetti',
                               'Ruby on Rails Ringer T-Shirt'])
    end

    it 'is able to visit category Mugs' do
      visit '/t/categories/mugs'

      expect(page).to have_css('.product-component-name').twice
      tmp = page.all('.product-component-name').map(&:text).flatten.compact
      expect(tmp.sort!).to eq(['Ruby on Rails Mug', 'Ruby on Rails Stein'])
    end

    it 'is able to visit category Bags' do
      visit '/t/categories/bags'

      expect(page).to have_css('.product-component-name').twice
      tmp = page.all('.product-component-name').map(&:text).flatten.compact
      expect(tmp.sort!).to eq(['Ruby on Rails Bag', 'Ruby on Rails Tote'])
    end
  end
end
