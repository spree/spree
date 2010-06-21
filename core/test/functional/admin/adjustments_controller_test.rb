require 'test_helper'

class Admin::AdjustmentsControllerTest < ActionController::TestCase
  context "given order" do
    setup do
      UserSession.create(Factory(:admin_user))
      @order =  Factory(:order)
    end

    context "on GET to :index" do
      setup do
        @params = { :order_id => @order.number }
        get :index
      end

      should_assign_to :order
      should_assign_to :adjustments
      should_respond_with :success
      should_render_template "index"

      should "render a table listing adjustments" do
        assert_select 'table.index' do

          @order.reload.adjustments.each do |adjustment|
            assert_select "tr[id='#{adjustment['type'].to_s.tableize.singularize}_#{adjustment.id}']"
          end
        end
      end
    end

    context "on GET to :edit" do
      setup do
        @adjustment =  @order.reload.adjustments.first
        @params = { :id => @adjustment.id, :order_id => @order.number, }
        get :edit
      end

      should_assign_to :order
      should_assign_to :adjustment
      should_respond_with :success
      should_render_template "edit"

      should "render a form" do
        assert_select "form[id='edit_#{@adjustment['type'].to_s.tableize.singularize}_#{@adjustment.id}']"
        assert_select "input[id='adjustment_amount']"   #{[value=?]", @adjustment.amount
        assert_select "select[id='adjustment_type'][disabled='disabled'] option[selected='selected'][value=?]", @adjustment['type']
        assert_select "textarea[id='adjustment_description']", :text => @adjustment.description
        assert_select "button[type='submit'] span", :text => I18n.t("continue")
        assert_select "a[href=?]", admin_order_adjustments_url(@order), :text => I18n.t("actions.cancel")
      end
    end

    context "on GET to :new" do
      setup do
        @params = { :order_id => @order.number, }
        get :new
      end

      should_assign_to :order
      should_assign_to :adjustment
      should_respond_with :success
      should_render_template "new"

      should "render a form" do
        assert_select "form[id='new_adjustment']"
        assert_select "input[id='adjustment_amount']"
        assert_select "select[id='adjustment_type']"
        assert_select "textarea[id='adjustment_description']"
        assert_select "button[type='submit'] span", :text => I18n.t("continue")
        assert_select "a[href=?]", admin_order_adjustments_url(@order), :text => I18n.t("actions.cancel")
      end
    end

    context "on POST to :create with type => Charge" do
      setup do
        post :create, {
            "order_id" => @order.number,
            "adjustment" => { "amount" => "19.99",
                              "adjustment_source_id" => @order.id,
                              "adjustment_source_type" => "Order",
                              "type" => "Charge",
                              "description" => "Additional Charge"}
        }

        @order.reload
      end

      should_create :adjustment
      should_respond_with :redirect

      should_change("@order.total", :by => 19.99) { @order.total.to_f }
      should_change("@order.charges.total", :by => 19.99) { @order.charges.total.to_f }
      should_change("Adjustment.count", :by => 1) { Adjustment.count }
      should_change("Charge.count", :by => 1) { Charge.count }
    end

    context "on POST to :create with type => Credit" do
      setup do
        post :create, {
            "order_id" => @order.number,
            "adjustment" => { "amount" => 5.00 ,
                              "adjustment_source_id" => @order.id,
                              "adjustment_source_type" => "Order",
                              "type" => "Credit",
                              "description" => "Additional Credit"}
        }

        @order.reload
      end

      should_create :adjustment
      should_assign_to :adjustment
      should_respond_with :redirect

      should_change("@order.total", :by => -5.00) { @order.total.to_f }
      should_change("@order.credits.total", :by => 5.00) { @order.credits.total.to_f }
      should_change("Adjustment.count", :by => 1) { Adjustment.count }
      should_change("Credit.count", :by => 1) { Credit.count }
    end

    context "on PUT to :update with type => Charge" do
      setup do
        @adjustment = Factory(:charge, :order => @order)
        put :update, {
            "id" => @adjustment.id,
            "order_id" => @order.number,
            "adjustment" => { "amount" => "9.99",
                              "adjustment_source_id" => @order.id,
                              "adjustment_source_type" => "Order",
                              "description" => "Additional Charge"}
        }

        @order.reload
      end

      should_respond_with :redirect

      should_change("@order.total", :by => 9.99) { @order.total.to_f }
      should_change("@order.charges.total", :by => 9.99) { @order.charges.total.to_f }
    end

    context "on PUT to :update with type => Credit" do
      setup do
        @adjustment = Factory(:credit, :order => @order)
        put :update, {
            "id" => @adjustment.id,
            "order_id" => @order.number,
            "adjustment" => { "amount" => "12.99",
                              "adjustment_source_id" => @order.id,
                              "adjustment_source_type" => "Order",
                              "description" => "Additional Credit"}
        }

        @order.reload
      end

      should_respond_with :redirect

      should_change("@order.total", :by => -12.99) { @order.total.to_f }
      should_change("@order.credits.total", :by => -12.99) { @order.credits.total.to_f }
    end

  end

end
