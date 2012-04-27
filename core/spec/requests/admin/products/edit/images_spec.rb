require 'spec_helper'

describe "Product Images" do
  context "uploading and editing an image", :js => true do
    it "should allow an admin to upload and edit an image for a product" do
      Spree::Image.attachment_definitions[:attachment].delete :storage

      create(:product, :name => 'apache baseball cap', :sku => 'A100', :available_on => "2011-01-01 01:01:01", :count_on_hand => 10)

      visit spree.admin_path
      click_link "Products"
      click_link "Edit"
      click_link "Images"
      click_link "new_image_link"
      absolute_path = File.expand_path(Rails.root.join('..', '..', 'spec', 'support', 'ror_ringer.jpeg'))
      attach_file('image_attachment', absolute_path)
      click_button "Update"
      page.should have_content("successfully created!")
      click_link "Edit"
      fill_in "image_alt", :with => "ruby on rails t-shirt"
      click_button "Update"
      page.should have_content("successfully updated!")
      page.should have_content("ruby on rails t-shirt")
    end
  end
end
