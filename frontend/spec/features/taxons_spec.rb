require 'spec_helper'

describe "viewing products", type: :feature, inaccessible: true do
  let!(:taxonomy) { create(:taxonomy, name: "Category") }
  let!(:super_clothing) { taxonomy.root.children.create(name: "Super Clothing") }
  let!(:t_shirts) { super_clothing.children.create(name: "T-Shirts") }
  let!(:xxl) { t_shirts.children.create(name: "XXL") }
  let!(:product) do
    product = create(:product, name: "Superman T-Shirt")
    product.taxons << t_shirts
  end
  let(:metas) { { meta_description: 'Brand new Ruby on Rails TShirts', meta_title: "Ruby On Rails TShirt", meta_keywords: 'ror, tshirt, ruby' } }
  let(:store_name) do
    ((first_store = Spree::Store.first) && first_store.name).to_s
  end

  # Regression test for #1796
  it "can see a taxon's products, even if that taxon has child taxons" do
    visit '/t/category/super-clothing/t-shirts'
    expect(page).to have_content("Superman T-Shirt")
  end

  it "shouldn't show nested taxons with a search" do
    visit '/t/category/super-clothing?keywords=shirt'
    expect(page).to have_content("Superman T-Shirt")
    expect(page).not_to have_selector("div[data-hook='taxon_children']")
  end

  describe 'breadcrumbs' do
    before do
      visit '/t/category/super-clothing/t-shirts'
    end
    it "should render breadcrumbs" do
      expect(page.find("#breadcrumbs")).to have_link("T-Shirts")
    end
    it "should mark last breadcrumb as active" do
      expect(page.find('#breadcrumbs .active')).to have_link("T-Shirts")
    end
  end

  describe 'meta tags and title' do
    it 'displays metas' do
      t_shirts.update_attributes metas
      visit '/t/category/super-clothing/t-shirts'
      expect(page).to have_meta(:description, 'Brand new Ruby on Rails TShirts')
      expect(page).to have_meta(:keywords, 'ror, tshirt, ruby')
    end

    it 'display title if set' do
      t_shirts.update_attributes metas
      visit '/t/category/super-clothing/t-shirts'
      expect(page).to have_title("Ruby On Rails TShirt")
    end

    it 'displays title from taxon root and taxon name' do
      visit '/t/category/super-clothing/t-shirts'
      expect(page).to have_title('Category - T-Shirts - ' + store_name)
    end

    # Regression test for #2814
    it "doesn't use meta_title as heading on page" do
      t_shirts.update_attributes metas
      visit '/t/category/super-clothing/t-shirts'
      within("h1.taxon-title") do
        expect(page).to have_content(t_shirts.name)
      end
    end

    it 'uses taxon name in title when meta_title set to empty string' do
      t_shirts.update_attributes meta_title: ''
      visit '/t/category/super-clothing/t-shirts'
      expect(page).to have_title('Category - T-Shirts - ' + store_name)
    end
  end

  context "taxon pages" do
    include_context "custom products"
    before do
      visit spree.root_path
    end

    it "should be able to visit brand Ruby on Rails" do
      within(:css, '#taxonomies') { click_link "Ruby on Rails" }

      expect(page.all('#products .product-list-item').size).to eq(7)
      tmp = page.all('#products .product-list-item a').map(&:text).flatten.compact
      tmp.delete("")
      array = ["Ruby on Rails Bag",
       "Ruby on Rails Baseball Jersey",
       "Ruby on Rails Jr. Spaghetti",
       "Ruby on Rails Mug",
       "Ruby on Rails Ringer T-Shirt",
       "Ruby on Rails Stein",
       "Ruby on Rails Tote"]
      expect(tmp.sort!).to eq(array)
    end

    it "should be able to visit brand Ruby" do
      within(:css, '#taxonomies') { click_link "Ruby" }

      expect(page.all('#products .product-list-item').size).to eq(1)
      tmp = page.all('#products .product-list-item a').map(&:text).flatten.compact
      tmp.delete("")
      expect(tmp.sort!).to eq(["Ruby Baseball Jersey"])
    end

    it "should be able to visit brand Apache" do
      within(:css, '#taxonomies') { click_link "Apache" }

      expect(page.all('#products .product-list-item').size).to eq(1)
      tmp = page.all('#products .product-list-item a').map(&:text).flatten.compact
      tmp.delete("")
      expect(tmp.sort!).to eq(["Apache Baseball Jersey"])
    end

    it "should be able to visit category Clothing" do
      click_link "Clothing"

      expect(page.all('#products .product-list-item').size).to eq(5)
      tmp = page.all('#products .product-list-item a').map(&:text).flatten.compact
      tmp.delete("")
      expect(tmp.sort!).to eq(["Apache Baseball Jersey",
     "Ruby Baseball Jersey",
     "Ruby on Rails Baseball Jersey",
     "Ruby on Rails Jr. Spaghetti",
     "Ruby on Rails Ringer T-Shirt"])
    end

    it "should be able to visit category Mugs" do
      click_link "Mugs"

      expect(page.all('#products .product-list-item').size).to eq(2)
      tmp = page.all('#products .product-list-item a').map(&:text).flatten.compact
      tmp.delete("")
      expect(tmp.sort!).to eq(["Ruby on Rails Mug", "Ruby on Rails Stein"])
    end

    it "should be able to visit category Bags" do
      click_link "Bags"

      expect(page.all('#products .product-list-item').size).to eq(2)
      tmp = page.all('#products .product-list-item a').map(&:text).flatten.compact
      tmp.delete("")
      expect(tmp.sort!).to eq(["Ruby on Rails Bag", "Ruby on Rails Tote"])
    end
  end
end
