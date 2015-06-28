require 'spec_helper'

describe "Customer Details", type: :feature do
  stub_authorization!

  let(:country) { create(:country, name: "Kangaland") }
  let(:state) { create(:state, name: "Alabama", country: country) }
  let!(:shipping_method) { create(:shipping_method, display_on: "front_end") }
  let!(:order) { create(:order, state: 'complete', completed_at: "2011-02-01 12:36:15") }
  let!(:product) { create(:product_in_stock) }

  # We need a unique name that will appear for the customer dropdown
  let!(:ship_address) { create(:address, country: country, state: state, first_name: "Rumpelstiltskin") }
  let!(:bill_address) { create(:address, country: country, state: state, first_name: "Rumpelstiltskin") }

  let!(:user) { create(:user, email: 'foobar@example.com', ship_address: ship_address, bill_address: bill_address) }

  context "brand new order" do
    before do
      visit spree.new_admin_order_path
    end
    # Regression test for #3335 & #5317
    it "associates a user when not using guest checkout", js: true do
      click_on "Add Item"
      select2_search product.name, from: Spree.t(:name_or_sku)
      within("table.stock-levels") do
        fill_in "variant_quantity", with: 1
        click_icon :add
      end
      wait_for_ajax
      click_link "Customer"
      click_on "Change Customer"
      click_on "Search"
      within("table#listing_users") do
        within_row(1) do
          first('td > a').click
        end
      end

      fill_in_address "bill"

      click_button "Update"
      expect(Spree::Order.last.user_id).not_to be_nil
    end
  end

  context "editing an order" do
    before do
      configure_spree_preferences do |config|
        config.default_country_id = country.id
        config.company = true
      end

      visit spree.admin_orders_path
      within('table#listing_orders') { click_icon(:edit) }
    end

    context "selected country has no state" do
      before { create(:country, iso: "BRA", name: "Brazil", states_required: true) }

      it "changes state field to text input" do
        click_link "Customer"

        within(".billing-address") do
          click_on "Edit"
          targetted_select2 "Brazil", from: "#s2id_order_bill_address_attributes_country_id"
          fill_in "order_bill_address_attributes_state_name", with: "Piaui"
        end

        click_button "Update"

        within(".billing-address") do
          click_on "Edit"
        end

        expect(find_field("order_bill_address_attributes_state_name").value).to eq("Piaui")
      end
    end

    it "should be able to update customer details for an existing order" do
      order.ship_address = create(:address)
      order.save!

      click_link "Customer"

      within(".billing-address") do
        click_on "Edit"
        fill_in_address "bill"
      end

      click_button "Update"
      click_link "Overview"

      # Regression test for #2950 + #2433
      # This act should transition the state of the order as far as it will go too
      within(".additional-info") do
        within(".state") do
          expect(page).to have_content("complete")
        end
      end
    end

    it "should show validation errors" do
      click_link "Customer"

      within(".billing-address") do
        click_on "Edit"
        fill_in "order_bill_address_attributes_firstname", with: ""
      end

      click_button "Update"
      expect(page).to have_content("Billing address first name can't be blank")
    end

    it "updates order email for an existing order with a user" do
      order.update_columns(ship_address_id: ship_address.id, bill_address_id: bill_address.id, state: "confirm", completed_at: nil)
      previous_user = order.user
      click_link "Customer"
      fill_in "order_email", with: "newemail@example.com"
      expect { click_button "Update" }.to change { order.reload.email }.to "newemail@example.com"
      expect(order.user_id).to eq previous_user.id
      expect(order.user.email).to eq previous_user.email
    end

    context "country associated was removed" do
      let(:brazil) { create(:country, iso: "BRA", name: "Brazil") }

      before do
        order.bill_address.country.destroy
        configure_spree_preferences do |config|
          config.default_country_id = brazil.id
        end
      end

      it "sets default country when displaying form" do
        click_link "Customer"

        within(".billing-address") do
          click_on "Edit"
        end

        expect(find_field("order_bill_address_attributes_country_id").value.to_i).to eq brazil.id
      end
    end

    # Regression test for #942
    # I dont get this test, context says it errors, expect no errors?
    context "errors when no shipping methods are available" do
      before do
        Spree::ShippingMethod.delete_all
      end

      specify do
        click_link "Customer"

        within(".billing-address") do
          click_on "Edit"
        end

        # Need to fill in valid information so it passes validations
        fill_in_address "bill"

        expect { click_button "Update" }.not_to raise_error
      end
    end
  end

  def fill_in_address(kind = "bill")
    fill_in "First Name",              with: "John 99"
    fill_in "Last Name",               with: "Doe"
    fill_in "Company",                 with: "Company"
    fill_in "Street Address",          with: "100 first lane"
    fill_in "Street Address (cont'd)", with: "#101"
    fill_in "City",                    with: "Bethesda"
    fill_in "Zip",                     with: "20170"
    targetted_select2 "Alabama",       from: "#s2id_order_#{kind}_address_attributes_state_id"
    fill_in "Phone",                   with: "123-456-7890"
  end
end
