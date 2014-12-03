require 'spec_helper'

describe "Customer Details", type: :feature, js: true do
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
    # Regression test for #3335 & #5317
    it "associates a user when not using guest checkout" do
      visit spree.new_admin_order_path
      select2_search product.name, from: Spree.t(:name_or_sku)
      within("table.stock-levels") do
        fill_in "variant_quantity", with: 1
        click_icon :plus
      end
      wait_for_ajax
      click_link "Customer Details"
      targetted_select2 "foobar@example.com", from: "#s2id_customer_search"
      # 5317 - Address prefills using user's default.
      expect(find('#order_bill_address_attributes_firstname').value).to eq user.bill_address.firstname
      expect(find('#order_bill_address_attributes_lastname').value).to eq user.bill_address.lastname
      expect(find('#order_bill_address_attributes_address1').value).to eq user.bill_address.address1
      expect(find('#order_bill_address_attributes_address2').value).to eq user.bill_address.address2
      expect(find('#order_bill_address_attributes_city').value).to eq user.bill_address.city
      expect(find('#order_bill_address_attributes_zipcode').value).to eq user.bill_address.zipcode
      expect(find('#order_bill_address_attributes_country_id').value).to eq user.bill_address.country_id.to_s
      expect(find('#order_bill_address_attributes_state_id').value).to eq user.bill_address.state_id.to_s
      expect(find('#order_bill_address_attributes_phone').value).to eq user.bill_address.phone
      click_button "Update"
      expect(Spree::Order.last.user).not_to be_nil
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
      before { create(:country, iso: "BRA", name: "Brazil") }

      it "changes state field to text input" do
        click_link "Customer Details"

        within("#billing") do
          targetted_select2 "Brazil", from: "#s2id_order_bill_address_attributes_country_id"
          fill_in "order_bill_address_attributes_state_name", with: "Piaui"
        end

        click_button "Update"
        expect(find_field("order_bill_address_attributes_state_name").value).to eq("Piaui")
      end
    end

    it "should be able to update customer details for an existing order" do
      order.ship_address = create(:address)
      order.save!

      click_link "Customer Details"
      within("#shipping") { fill_in_address "ship" }
      within("#billing") { fill_in_address "bill" }

      click_button "Update"
      click_link "Customer Details"

      # Regression test for #2950 + #2433
      # This act should transition the state of the order as far as it will go too
      within("#order_tab_summary") do
        expect(find(".state").text).to eq("COMPLETE")
      end
    end

    it "should show validation errors" do
      click_link "Customer Details"
      click_button "Update"
      expect(page).to have_content("Shipping address first name can't be blank")
    end

    it "updates order email for an existing order with a user" do
      order.update_columns(ship_address_id: ship_address.id, bill_address_id: bill_address.id, state: "confirm", completed_at: nil)
      previous_user = order.user
      click_link "Customer Details"
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
        click_link "Customer Details"
        expect(find_field("order_bill_address_attributes_country_id").value.to_i).to eq brazil.id
      end
    end

    # Regression test for #942
    context "errors when no shipping methods are available" do
      before do
        Spree::ShippingMethod.delete_all
      end

      specify do
        click_link "Customer Details"
        # Need to fill in valid information so it passes validations
        fill_in "order_ship_address_attributes_firstname",  with: "John 99"
        fill_in "order_ship_address_attributes_lastname",   with: "Doe"
        fill_in "order_ship_address_attributes_lastname",   with: "Company"
        fill_in "order_ship_address_attributes_address1",   with: "100 first lane"
        fill_in "order_ship_address_attributes_address2",   with: "#101"
        fill_in "order_ship_address_attributes_city",       with: "Bethesda"
        fill_in "order_ship_address_attributes_zipcode",    with: "20170"

        page.select('Alabama', from: 'order_ship_address_attributes_state_id')
        fill_in "order_ship_address_attributes_phone", with: "123-456-7890"
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
