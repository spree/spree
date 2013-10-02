require 'spec_helper'

module Spree
  describe "Countries" do
    stub_authorization!

    it "deletes a state", js: true do
      visit spree.admin_countries_path
      click_link "New Country"

      fill_in "Name", with: "Brazil"
      fill_in "Iso Name", with: "BRL"
      click_button "Create"

      click_icon :trash
      page.driver.browser.switch_to.alert.accept
      wait_for_ajax

      expect { Country.find(country.id) }.to raise_error
    end
  end
end
