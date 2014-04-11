require 'spec_helper'

describe "viewing products" do
  let!(:taxonomy) { create(:taxonomy, :name => "Category") }
  let!(:super_clothing) { taxonomy.root.children.create(:name => "Super Clothing") }
  let!(:t_shirts) { super_clothing.children.create(:name => "T-Shirts") }
  let!(:xxl) { t_shirts.children.create(:name => "XXL") }
  let!(:product) do
    product = create(:product, :name => "Superman T-Shirt")
    product.taxons << t_shirts
  end
  let(:metas) { { :meta_description => 'Brand new Ruby on Rails TShirts', :meta_title => "Ruby On Rails TShirt", :meta_keywords => 'ror, tshirt, ruby' } }

  # Regression test for #1796
  it "can see a taxon's products, even if that taxon has child taxons" do
    visit '/t/category/super-clothing/t-shirts'
    page.should have_content("Superman T-Shirt")
  end

  it "shouldn't show nested taxons with a search" do
    visit '/t/category/super-clothing?keywords=shirt'
    page.should have_content("Superman T-Shirt")
    page.should_not have_selector("div[data-hook='taxon_children']")
  end

  describe 'meta tags and title' do

    after do
      Capybara.ignore_hidden_elements = true
    end

    before do
      Capybara.ignore_hidden_elements = false
    end

    it 'displays metas' do
      t_shirts.update_attributes metas
      visit '/t/category/super-clothing/t-shirts'
      page.should have_meta(:description, 'Brand new Ruby on Rails TShirts')
      page.should have_meta(:keywords, 'ror, tshirt, ruby')
    end

    it 'display title if set' do
      t_shirts.update_attributes metas
      visit '/t/category/super-clothing/t-shirts'
      page.should have_title("Ruby On Rails TShirt")
    end

    it 'display title from taxon root and taxon name' do
      visit '/t/category/super-clothing/t-shirts'
      page.should have_title('Category - T-Shirts - Spree Demo Site')
    end

    # Regression test for #2814
    it "doesn't use meta_title as heading on page" do
      t_shirts.update_attributes metas
      visit '/t/category/super-clothing/t-shirts'
      within("h1.taxon-title") do
        page.should have_content(t_shirts.name)
      end
    end
  end

  context "taxon pages" do
    include_context "custom products"
    before do
      visit spree.root_path
    end

    it "should be able to visit brand Ruby on Rails" do
      within(:css, '#taxonomies') { click_link "Ruby on Rails" }

      page.all('ul.product-listing li').size.should == 7
      tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
      tmp.delete("")
      array = ["Ruby on Rails Bag",
       "Ruby on Rails Baseball Jersey",
       "Ruby on Rails Jr. Spaghetti",
       "Ruby on Rails Mug",
       "Ruby on Rails Ringer T-Shirt",
       "Ruby on Rails Stein",
       "Ruby on Rails Tote"]
      tmp.sort!.should == array
    end

    it "should be able to visit brand Ruby" do
      within(:css, '#taxonomies') { click_link "Ruby" }

      page.all('ul.product-listing li').size.should == 1
      tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
      tmp.delete("")
      tmp.sort!.should == ["Ruby Baseball Jersey"]
    end

    it "should be able to visit brand Apache" do
      within(:css, '#taxonomies') { click_link "Apache" }

      page.all('ul.product-listing li').size.should == 1
      tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
      tmp.delete("")
      tmp.sort!.should == ["Apache Baseball Jersey"]
    end

    it "should be able to visit category Clothing" do
      click_link "Clothing"

      page.all('ul.product-listing li').size.should == 5
      tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
      tmp.delete("")
      tmp.sort!.should == ["Apache Baseball Jersey",
     "Ruby Baseball Jersey",
     "Ruby on Rails Baseball Jersey",
     "Ruby on Rails Jr. Spaghetti",
     "Ruby on Rails Ringer T-Shirt"]
    end

    it "should be able to visit category Mugs" do
      click_link "Mugs"

      page.all('ul.product-listing li').size.should == 2
      tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
      tmp.delete("")
      tmp.sort!.should == ["Ruby on Rails Mug", "Ruby on Rails Stein"]
    end

    it "should be able to visit category Bags" do
      click_link "Bags"

      page.all('ul.product-listing li').size.should == 2
      tmp = page.all('ul.product-listing li a').map(&:text).flatten.compact
      tmp.delete("")
      tmp.sort!.should == ["Ruby on Rails Bag", "Ruby on Rails Tote"]
    end
  end
end
