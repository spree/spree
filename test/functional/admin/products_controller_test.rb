require 'test_helper'

class Admin::ProductsControllerTest < ActionController::TestCase
  context "on get to :index" do
    setup do
      UserSession.create(Factory(:admin_user))
      get :index
    end

    should_respond_with :success
    should_not_set_the_flash
    should_assign_to :products
    should_render_template "index"

    should "render a table listing products" do
      assert_select 'table.index' do
        assigns(:products).each do |product|
          assert_select "tr[id='product_#{product.id}']"
        end
      end
    end

    should "render sibebar search" do
      assert_select "div#sidebar" do
         assert_select "form[action='/admin/products']" do
           assert_select "input[id='search_name_contains']"
           assert_select "input[id='search_variants_including_master_sku_contains']"
           assert_select "input[id='search_deleted_at_not_null'][type='checkbox']"
           assert_select "button[type='submit']", :text => I18n.t('search')
         end
      end
    end
  end

  context "on get to :index with search params" do
    setup do
      UserSession.create(Factory(:admin_user))
      Factory.create(:product,  :name => "Rails Mug")

      @tote = Factory.create(:product,  :name => "Rails Tote")
      3.times do
        Factory.create(:variant, :product => @tote)
      end
    end

    context "and format = html" do
      setup do
        get :index, "search" => {
            "name_contains" => "rails",
            "order" => "ascend_by_name",
            "deleted_at_not_null" => ""}
      end

      should "match two products" do
        assert_equal 2, assigns(:products).size
      end

      should_respond_with :success
      should_not_set_the_flash
      should_assign_to :products
      should_render_template "index"
      should_respond_with_content_type :html

      should "render a table listing products" do
        assert_select 'table.index' do
          assigns(:products).each do |product|
            assert_select "tr[id='product_#{product.id}']"
          end
        end
      end

      should "render sibebar search" do
        assert_select "div#sidebar" do
           assert_select "form[action='/admin/products']" do
             assert_select "input[id='search_name_contains'][value=?]", "rails"
             assert_select "input[id='search_variants_including_master_sku_contains']"
             assert_select "input[id='search_deleted_at_not_null'][type='checkbox']"
             assert_select "button[type='submit']", :text => I18n.t('search')
           end
        end
      end


    end

    context "and format = json" do
      setup do
        get :index,
          "format" => "json",
          "search" => {
            "name_contains" => "rails",
            "order" => "ascend_by_name",
            "deleted_at_not_null" => ""}

      end
      should "match two products" do
        assert_equal 2, assigns(:products).size
      end

      should_respond_with :success
      should_not_set_the_flash
      should_assign_to :products
      should_respond_with_content_type :json

      context "returned json" do
        setup do
          @json = JSON.parse(@response.body)
        end

        should "contain 2 products" do
          assert_equal 2, @json.size
        end

        should "contain 1 product with no variants" do
          count = 0
          @json.each do |record|
            if record['product']['variants'].size == 0

              assert record['product']['master'].keys.include?('is_master')
              assert record['product']['master']['is_master']
              assert record['product'].keys.include?('images')

              count += 1
            end
          end

          assert_equal 1, count
        end

        should "contain 1 product with 3 variants" do
           count = 0
           @json.each do |record|
             if record['product']['variants'].size != 0
               assert_equal 3, record['product']['variants'].size
               count += 1
             end
           end

           assert_equal 1, count
         end
      end
    end
  end

  context "on POST to :create" do
    setup do
      UserSession.create(Factory(:admin_user))
      @tax_category = Factory.create(:tax_category)
      Spree::Config.set :default_tax_category => @tax_category.name

      assert_difference "Product.count", 1 do
        post :create, :product => {
          :name  => "Test Product",
          :price => "12.99"
        }
      end
    end

    should_respond_with :redirect
    should_redirect_to("the product's edit page") { edit_admin_product_path(assigns(:product)) }
    should_assign_to :product
    should "set the default tax category" do
      assert_equal @tax_category, assigns(:product).tax_category
    end
  end
end
