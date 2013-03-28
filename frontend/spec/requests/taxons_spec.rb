require 'spec_helper'

describe "viewing products" do
  let!(:taxonomy) { create(:taxonomy, :name => "Category") }
  let!(:clothing) { taxonomy.root.children.create(:name => "Clothing") }
  let!(:t_shirts) { clothing.children.create(:name => "T-Shirts") }
  let!(:xxl) { t_shirts.children.create(:name => "XXL") }
  let!(:product) do
    product = create(:product, :name => "Superman T-Shirt")
    product.taxons << t_shirts
  end
  let(:metas) { { :meta_description => 'Brand new Ruby on Rails TShirts', :meta_title => "Ruby On Rails TShirt", :meta_keywords => 'ror, tshirt, ruby' } }

  # Regression test for #1796
  it "can see a taxon's products, even if that taxon has child taxons" do
    visit '/t/category/clothing/t-shirts'
    page.should have_content("Superman T-Shirt")
  end

  it "shouldn't show nested taxons with a search" do
    visit '/t/category/clothing?keywords=shirt'
    page.should have_content("Superman T-Shirt")
    page.should_not have_selector("div[data-hook='taxon_children']")
  end

  describe 'meta tags and title' do

    it 'displays metas' do
      t_shirts.update_attributes metas
      visit '/t/category/clothing/t-shirts'
      page.should have_meta(:description, 'Brand new Ruby on Rails TShirts')
      page.should have_meta(:keywords, 'ror, tshirt, ruby')
    end

    it 'display title if set' do
      t_shirts.update_attributes metas
      visit '/t/category/clothing/t-shirts'
      page.should have_title("Ruby On Rails TShirt")
    end

    it 'display title from taxon root and taxon name' do
      visit '/t/category/clothing/t-shirts'
      page.should have_title('Category - T-Shirts - Spree Demo Site')
    end

  end
end
