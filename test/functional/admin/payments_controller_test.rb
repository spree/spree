require 'test_helper'

class Admin::PaymentsControllerTest < ActionController::TestCase
  fixtures :payment_methods, :countries

  context "given order" do
    setup do
      Spree::Config.set(:auto_capture => true) 
      UserSession.create(Factory(:admin_user))
      create_new_order_v2
      @order.reload
      # Add a charge to create an outstanding balance on the order so new payments will validate
      @charge = Factory(:charge, :amount => 2.99, :order => @order)
      @order.update_totals!
      @order.reload
    end

    context "on POST to :create" do

      context "entering a new creditcard" do
        setup do
          @params = {
            :payment_type => 'creditcard_payment',
            :order_id => @order.id, 
            :card => 'new',
            :payment => {
              :amount => '2.99',
              :payment_method_id => payment_methods(:bogus_test).id.to_s
            },
            :payment_source => {Gateway.current.id.to_s => Factory.attributes_for(:creditcard)}
          }
          post :create, @params
        end
        should_create :payment
        should_create :creditcard_txn
        should_respond_with :redirect
        should "create payment with the right attributes" do
          assert_equal 1, @order.payments.count
          assert_equal 2.99, @order.payments.last.source.txns.last.amount.to_f
        end
      end

      context "selected existing creditcard with CIM gateway" do
        setup do
          PaymentMethod.update_all(:active => false)
          payment_methods(:authorize_net_cim_test).update_attribute(:active, true)
          @creditcard = Factory(:creditcard, :gateway_customer_profile_id => '123', :gateway_payment_profile_id => '456')
          @params = {
            :order_id => @order.id, 
            :card => @creditcard.id,
            :payment => {
              :amount => '2.99',
              :payment_method_id => payment_methods(:authorize_net_cim_test).id.to_s
            }
          }
          post :create, @params
          @order.reload
          @payment = @order.payments.first
        end
        should_create :payment
        should_respond_with :redirect
        should "create payment with the right attributes" do
          assert_equal @creditcard.id, @payment.source.id
          assert_equal 2.99, @payment.source.txns.last.amount.to_f
        end
      end
      

      context "for cheque payment" do
        setup do
          @params = {
            :order_id => @order.id, 
            :payment => {
              :payment_method_id => payment_methods(:check_payment_method).id.to_s, 
              :amount => '1.99'
            }
          }
          post :create, @params
        end
        should_create :payment
        should_respond_with :redirect
      end

    end

    context "on PUT to :finalize" do
      setup do
        @payment = Factory(:payment, :source => nil, :payment_method => payment_methods(:check_payment_method))
        @payment.process!
        put :finalize, {
          :order_id => @order.id,
          :id => @payment.id
        }
        @payment.reload
      end
      
      should "move payment from checkout to order" do
        assert_equal Order, @payment.payable.class
      end
    end

  end
end