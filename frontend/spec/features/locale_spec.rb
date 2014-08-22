require 'spec_helper'

describe "setting locale" do
  before do
    I18n.enforce_available_locales = false
    I18n.locale = I18n.default_locale
    I18n.backend.store_translations(:fr,
     :spree => {
       :cart => "Panier",
       :shopping_cart => "Panier"
    })
    Spree::Frontend::Config[:locale] = "fr"
  end

  after do
    I18n.locale = I18n.default_locale
    Spree::Frontend::Config[:locale] = "en"
    I18n.enforce_available_locales = true
  end

  it "should be in french" do
    visit spree.root_path
    click_link "Panier"
    page.should have_content("Panier")
  end
end
