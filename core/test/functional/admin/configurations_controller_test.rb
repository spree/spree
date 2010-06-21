require 'test_helper'

class Admin::ConfigurationsControllerTest < ActionController::TestCase
  setup do
    UserSession.create(Factory(:admin_user))
  end

  context "on GET to :index" do
    setup do
      get :index
    end

    should_respond_with :success
    should_render_template "index"

    should "display a Mail Server Settings link" do
      assert_select('a[href=?]', admin_mail_settings_path)
    end

    should "display a Tax Categories link" do
      assert_select 'a[href=?]', admin_tax_categories_path
    end

    should "display a Zones link" do
      assert_select 'a[href=?]', admin_zones_path
    end

    should "display a States link" do
      assert_select 'a[href=?]', admin_country_states_path(214)
    end

    should "display a Payment Methods link" do
      assert_select 'a[href=?]', admin_payment_methods_path
    end

    should "display an Inventory Settings link" do
      assert_select 'a[href=?]', admin_inventory_settings_path
    end

  end
end
