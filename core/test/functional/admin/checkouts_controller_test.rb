require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class Admin::CheckoutsControllerTest < ActionController::TestCase
  fixtures :countries, :states

  context "given order" do
    setup do
      UserSession.create(Factory(:admin_user))
      @order = create_complete_order
    end

    context "on GET to :show" do
      setup do
        @checkout =  @order.checkout
        @params = { :id => @checkout.id, :order_id => @order.number, }
        get :show
      end

      should assign_to :order
      should assign_to :checkout
      should respond_with :success
      should render_template "show"

      should "render address details" do
        assert_select "table" do
          assert_select "th", :text => I18n.t("billing_address")
        end

        assert_select "table" do
          assert_select "th", :text => I18n.t("shipping_address")

        end
      end
    end

    context "on GET to :edit" do
      setup do
        @checkout =  @order.checkout
        @params = { :id => @checkout.id, :order_id => @order.number, }

        @checkout.bill_address.state_name = nil
        @checkout.bill_address.state = @checkout.bill_address.country.states.last

        @checkout.ship_address = Factory(:address)
        @checkout.ship_address.country = Factory.create(:country, :states => [])

        @checkout.save
        get :edit
      end

      should assign_to :order
      should assign_to :checkout
      should respond_with :success
      should render_template "edit"

      should "render address details" do
        assert_select "table" do
          assert_select "input[id='checkout_bill_address_attributes_firstname'][value=?]", @checkout.bill_address.firstname
          assert_select "input[id='checkout_bill_address_attributes_lastname'][value=?]", @checkout.bill_address.lastname
          assert_select "input[id='checkout_bill_address_attributes_address1'][value=?]", @checkout.bill_address.address1
          assert_select "input[id='checkout_bill_address_attributes_address2'][value=?]", @checkout.bill_address.address2
          assert_select "input[id='checkout_bill_address_attributes_city'][value=?]", @checkout.bill_address.city
          assert_select "input[id='checkout_bill_address_attributes_zipcode'][value=?]", @checkout.bill_address.zipcode

          assert_select "input[id='checkout_bill_address_attributes_state_name'][disabled='disabled']"
          assert_select "select[id='checkout_bill_address_attributes_state_id'] option[selected='selected'][value=?]", @checkout.bill_address.state.id.to_s

        end

        assert_select "table" do
          assert_select "input[id='checkout_ship_address_attributes_firstname'][value=?]", @checkout.ship_address.firstname
          assert_select "input[id='checkout_ship_address_attributes_lastname'][value=?]", @checkout.ship_address.lastname
          assert_select "input[id='checkout_ship_address_attributes_address1'][value=?]", @checkout.ship_address.address1
          assert_select "input[id='checkout_ship_address_attributes_address2'][value=?]", @checkout.ship_address.address2
          assert_select "input[id='checkout_ship_address_attributes_city'][value=?]", @checkout.ship_address.city
          assert_select "input[id='checkout_ship_address_attributes_zipcode'][value=?]", @checkout.ship_address.zipcode

          assert_select "input[id='checkout_ship_address_attributes_state_name'][value=?]", @checkout.ship_address.state_name
          assert_select "select[id='checkout_ship_address_attributes_state_id'][disabled='disabled']"
        end
      end
    end
  end
end
