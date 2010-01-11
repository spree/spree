require 'test_helper'

class Admin::PaymentsControllerTest < ActionController::TestCase
  fixtures :gateways

  context "given order" do
    setup do
      UserSession.create(Factory(:admin_user))
      create_new_order
      @order.reload
    end

    context "on POST to :create" do

      context "entering a new creditcard" do
        setup do
          @params = {
            :payment_type => 'creditcard_payment',
            :order_id => @order.id, 
            :card => 'new',
            :creditcard_payment => {
              :amount => '2.99',
              :creditcard_attributes => Factory.attributes_for(:creditcard),
              :order_attributes => {
                :checkout_attributes => {
                  :bill_address_attributes => Factory.attributes_for(:address)
                }
              }
            }
          }
          post :create, @params
        end
      
        should_create :creditcard_payment
        should_respond_with :redirect
        should "create payment with the right attributes" do
          assert_equal 2, @order.creditcard_payments.count
          assert_equal 2.99, @order.creditcard_payments.last.txns.last.amount.to_f
        end
      end

      context "selected existing creditcard with CIM gateway" do
        setup do
          Gateway.update_all(:active => false)
          gateways(:authorize_net_cim_test).update_attribute(:active, true)
          @creditcard = @order.checkout.creditcard
          # Set up a fake payment profile on the existing creditcard so we can test charging it again
          # Using a mock gateway so there just need to be some values in these fields
          @creditcard.update_attributes(:gateway_customer_profile_id => '123', :gateway_payment_profile_id => '456')
          @params = {
            :payment_type => 'creditcard_payment',
            :order_id => @order.id, 
            :card => @creditcard.id,
            :creditcard_payment => {
              :amount => '1.99',
            }
          }
          post :create, @params
        end
        should_create :creditcard_payment
        should_respond_with :redirect
        should "create payment with the right attributes" do
          assert_equal 2, @order.creditcard_payments.count
          assert_equal 1.99, @order.creditcard_payments.last.txns.last.amount.to_f
        end
        should "create payment that's assigned to the existing card" do
          assert_equal @creditcard, @order.creditcard_payments.last.creditcard
        end        
      end
      
      context "for cheque payment" do
        setup do
          @params = {
            :payment_type => 'cheque_payment',
            :order_id => @order.id, 
            :cheque_payment => {
              :amount => '1.99',
            }
          }
          post :create, @params
        end
        should_create :cheque_payment
        should_respond_with :redirect
      end

    end

  end
end