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

  # Regression test for #1796
  it "can see a taxon's products, even if that taxon has child taxons" do
    visit '/t/category/clothing/t-shirts'
    page.should have_content("Superman T-Shirt")
  end
end
