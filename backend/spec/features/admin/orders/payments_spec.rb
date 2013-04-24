require 'spec_helper'

describe "Payments" do
  stub_authorization!

  let(:order) { create(:completed_order_with_totals, :number => "R100", :state => "complete") }

  context "payment methods" do

    before(:each) do
      create(:payment, :order => order, :amount => order.outstanding_balance, :payment_method => create(:bogus_payment_method, :environment => 'test'))
      visit spree.admin_path
      click_link "Orders"
      within_row(1) do
        click_link "R100"
      end
    end

    it "should be able to list and create payment methods for an order", :js => true do

      click_link "Payments"
      find("#payment_status").text.should == "balance due"
      within_row(1) do
        column_text(2).should == "$50.00"
        column_text(3).should == "Credit Card"
        column_text(4).should == "checkout"
      end

      click_icon :void
      find("#payment_status").text.should == "balance due"
      page.should have_content("Payment Updated")

      within_row(1) do
        column_text(2).should == "$50.00"
        column_text(3).should == "Credit Card"
        column_text(4).should == "void"
      end

      click_on "New Payment"
      page.should have_content("New Payment")
      click_button "Update"
      page.should have_content("successfully created!")

      click_icon(:capture)
      find("#payment_status").text.should == "paid"

      page.should_not have_css('#new_payment_section')
    end

    # Regression test for #1269
    it "cannot create a payment for an order with no payment methods" do
      Spree::PaymentMethod.delete_all
      order.payments.delete_all

      visit spree.new_admin_order_payment_path(order)
      page.should have_content("You cannot create a payment for an order without any payment methods defined.")
      page.should have_content("Please define some payment methods first.")
    end

    # Regression tests for #1453
    context "with a check payment" do
      before do
        order.payments.delete_all
        create(:payment, :order => order,
                        :state => "checkout",
                        :amount => order.outstanding_balance,
                        :payment_method => create(:bogus_payment_method, :environment => 'test'))
      end

      it "capturing a check payment from a new order" do
        visit spree.admin_order_payments_path(order)
        click_icon(:capture)
        page.should_not have_content("Cannot perform requested operation")
        page.should have_content("Payment Updated")
      end

      it "voids a check payment from a new order" do
        visit spree.admin_order_payments_path(order)
        click_icon(:void)
        page.should have_content("Payment Updated")
      end
    end

  end
end
