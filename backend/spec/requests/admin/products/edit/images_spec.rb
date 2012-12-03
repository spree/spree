require 'spec_helper'

describe "Product Images" do
  stub_authorization!

  let(:file_path) { Rails.root + "../../spec/support/ror_ringer.jpeg" }

  context "uploading and editing an image", :js => true do
    it "should allow an admin to upload and edit an image for a product" do
      Spree::Image.attachment_definitions[:attachment].delete :storage

      create(:product)

      visit spree.admin_path
      click_link "Products"
      click_icon(:edit)
      click_link "Images"
      click_link "new_image_link"
      attach_file('image_attachment', file_path)
      click_button "Update"
      page.should have_content("successfully created!")
      click_icon(:edit)
      fill_in "image_alt", :with => "ruby on rails t-shirt"
      click_button "Update"
      page.should have_content("successfully updated!")
      page.should have_content("ruby on rails t-shirt")
    end
  end

  # Regression test for #2228
  it "should see variant images" do
    variant = create(:variant)
    variant.images.create!(:attachment => File.open(file_path))
    visit spree.admin_product_images_path(variant.product)

    page.should_not have_content("No Images Found.")
    within("table.index") do
      page.should have_content(variant.options_text)
    end
  end
end
