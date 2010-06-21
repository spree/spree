require 'test_helper'

class Admin::ReportsControllerTest < ActionController::TestCase
  context "sales report" do
    setup do
      @in_progress_order = create_complete_order
      @completed_order = Factory.create(:order)
      @completed_order.complete!
      assert_not_nil @completed_order.completed_at
    end

    context "on GET to :sales_report" do

      setup do
        UserSession.create(Factory(:admin_user))
        get :sales_total
      end

      should "only assign sums for completed orders" do
        @wrong_sum = @in_progress_order.total + @completed_order.total
        @right_sum = @completed_order.total
        assert_not_equal @wrong_sum, assigns(:sales_total)
        assert_equal @right_sum, assigns(:sales_total)
      end
    end
  end

end
