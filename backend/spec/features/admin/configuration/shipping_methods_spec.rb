require 'spec_helper'

describe "Shipping Methods", type: :feature do
  stub_authorization!
  let!(:zone) { create(:global_zone) }
  let!(:shipping_method) { create(:shipping_method, zones: [zone]) }

  after do
    Capybara.ignore_hidden_elements = true
  end

  before do
    Capybara.ignore_hidden_elements = false
    # HACK: To work around no email prompting on check out
    allow_any_instance_of(Spree::Order).to receive_messages(require_email: false)
    create(:check_payment_method)

    visit spree.admin_shipping_methods_path
  end

  context "show" do
    it "should display existing shipping methods" do
      within_row(1) do
        expect(column_text(1)).to eq(shipping_method.name)
        expect(column_text(2)).to eq(zone.name)
        expect(column_text(3)).to eq("Flat rate")
        expect(column_text(4)).to eq("Both")
      end
    end
  end

  context "create" do
    it "should be able to create a new shipping method" do
      click_link "New Shipping Method"

      fill_in "shipping_method_name", with: "bullock cart"

      within("#shipping_method_categories_field") do
        check first("input[type='checkbox']")["name"]
      end

      click_on "Create"
      expect(current_path).to eql(spree.edit_admin_shipping_method_path(Spree::ShippingMethod.last))
    end
  end

  # Regression test for #1331
  context "update" do
    it "can change the calculator", js: true do
      within("#listing_shipping_methods") do
        click_icon :edit
      end

      expect(find(:css, ".calculator-settings-warning")).not_to be_visible
      select2_search('Flexible Rate', from: 'Calculator')
      expect(find(:css, ".calculator-settings-warning")).to be_visible

      click_button "Update"
      expect(page).not_to have_content("Shipping method is not found")
    end
  end
end
