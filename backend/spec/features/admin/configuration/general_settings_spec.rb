require 'spec_helper'

describe "General Settings", type: :feature, js: true do
  stub_authorization!

  before(:each) do
    store = create(:store, name: 'Test Store', url: 'test.example.org',
                           mail_from_address: 'test@example.org')
    visit spree.edit_admin_general_settings_path
  end

  context "visiting general settings (admin)" do
    it "should have the right content" do
      expect(page).to have_content("General Settings")
      expect(find("#store_name").value).to eq("Test Store")
      expect(find("#store_url").value).to eq("test.example.org")
      expect(find("#store_mail_from_address").value).to eq("test@example.org")
    end
  end

  context "editing general settings (admin)" do
    it "should be able to update the site name" do
      fill_in "store_name", with: "Spree Demo Site99"
      fill_in "store_mail_from_address", with: "spree@example.org"
      click_button "Update"

      assert_successful_update_message(:general_settings)
      expect(find("#store_name").value).to eq("Spree Demo Site99")
      expect(find("#store_mail_from_address").value).to eq("spree@example.org")
    end
  end

  context "clearing the cache" do
    it "should clear the cache" do
      expect(page).to_not have_content(Spree.t(:clear_cache_ok))
      expect(page).to have_content(Spree.t(:clear_cache_warning))

      click_button "Clear Cache"

      expect(page).to have_content(Spree.t(:clear_cache_ok))
    end
  end
end
