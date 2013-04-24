require 'spec_helper'

describe "setting locale" do
  stub_authorization!

  before do
    I18n.locale = I18n.default_locale
    I18n.backend.store_translations(:fr,
      :date => {
        :month_names => [],
      },
      :spree => {
        :admin => {
          :tab => { :orders => "Ordres" }
        },
        :listing_orders => "Ordres",
      })
    Spree::Backend::Config[:locale] = "fr"
  end

  after do
    I18n.locale = I18n.default_locale
    Spree::Backend::Config[:locale] = "en"
  end

  it "should be in french" do
    visit spree.admin_path
    click_link "Ordres"
    page.should have_content("Ordres")
  end
end
