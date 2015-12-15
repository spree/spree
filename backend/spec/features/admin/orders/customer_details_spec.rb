require 'spec_helper'

describe 'Customer Details', type: :feature, js: true do
  stub_authorization!

  let(:store)           { create(:store, default: true)                     }
  let(:country)         { create(:country)                                  }
  let(:state)           { create(:state, country: country)                  }
  let(:shipping_method) { create(:shipping_method, display_on: 'front_end') }
  let(:product)         { create(:product_in_stock)                         }
  let!(:ship_address)   { create(:address, country: country, state: state)  }
  let!(:bill_address)   { create(:address, country: country, state: state)  }

  # We need a unique name that will appear for the customer dropdown

  let!(:order) do
    create(
      :order,
      store:        store,
      state:        'complete',
      completed_at: Time.now
    )
  end

  let!(:user) do
    create(
      :user,
      ship_address: ship_address,
      bill_address: bill_address
    )
  end

  context 'brand new order' do
    let(:exclude_address_attributes) do
      %w[id created_at state_name updated_at alternative_phone company]
    end

    # Expect address in form
    #
    # @param id_prefix [String]
    # @param address [Spree::Address]
    def expect_address(id_prefix, address)
      address.attributes.except(*exclude_address_attributes).each do |name, value|
        page.assert_selector(
          :field,
          "#{id_prefix}_#{name}",
          with: value
        )
      end
    end

    # Regression test for #3335 & #5317
    it 'associates a user when not using guest checkout' do
      visit spree.admin_path
      click_link 'Orders'
      click_link 'New Order'
      select2_search product.name, from: Spree.t(:name_or_sku)
      within('table.stock-levels') do
        fill_in 'variant_quantity', with: 1
        click_icon :plus
      end
      click_link 'Customer Details'
      targetted_select2 user.email, from: '#s2id_customer_search'
      expect_address('order_bill_address_attributes', user.bill_address)
      click_button 'Update'
      expect(Spree::Order.last.user).not_to be(nil)
    end
  end

  context "editing an order" do
    before do
      configure_spree_preferences do |config|
        config.default_country_id = country.id
        config.company = true
      end

      visit spree.admin_path
      click_link "Orders"
      within('table#listing_orders') { click_icon(:edit) }
    end

    context "selected country has no state" do
      before { create(:country, iso: 'BR', name: 'Brazil') }

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
      order.ship_address = create(:address, firstname: 'Sue')
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

        page.select(state.name, from: 'order_ship_address_attributes_state_id')
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
    targetted_select2 state.name,      from: "#s2id_order_#{kind}_address_attributes_state_id"
    fill_in "Phone",                   with: "123-456-7890"
  end
end
