 require 'test_helper'

class OrderStateTest < ActiveSupport::TestCase
  should "be in_progress initially" do
    assert Order.new.in_progress?
  end
  context "Order" do
      setup do
        @order = Order.create!
        @order.line_items << Factory(:line_item,:order=>@order,:price=>100, :quantity=>5)
        @order.checkout.ship_address = Factory(:address)
        @order.checkout.shipping_method = Factory(:shipping_method)
        @order.update_totals
        @order.payments = [Factory(:payment, :payable=>@order, :amount=>500)]
        @order.save!
      end

      context "with a complete checkout and payment" do
        setup do
          @order.complete!
          @order.update_totals!
        end

        should_change("@order.state", :from => "in_progress", :to => "new") { @order.state }

        should "allow cancel" do
          assert @order.can_cancel?
        end

        should "not allow resume" do
          assert !@order.can_resume?
        end

        context "when canceled" do
          setup do
            @order.cancel!
          end

          should_change("@order.state", :from => "new", :to => "canceled") { @order.state }
          should_change("@order.inventory_units.size", :to => 0) { @order.inventory_units.size }

          should "change all shipments to pending" do
            assert @order.shipments.all?(&:pending?)
          end

          should "allow resume" do
            assert @order.can_resume?
          end

          context "and then resumed" do
            setup do
              @order.resume!
            end

            should_change("@order.state", :from => "canceled", :to => "new") { @order.state }

            should "all shipments still be pending" do
              assert @order.shipments.all?(&:pending?)
            end
          end
        end

        context "when paid" do
          setup do
            @order.pay!
          end

          should "allow ship" do
            assert @order.can_ship?
          end

          context "and canceled" do
            setup do
              @order.cancel!
            end

            should_change("@order.state", :from => "paid", :to => "canceled") { @order.state }
            should_change("@order.inventory_units.size", :to => 0) { @order.inventory_units.size }

            should "change all shipments to pending" do
              assert @order.shipments.all?(&:pending?)
            end

            context "and then resumed" do
              setup do
                @order.resume!
                @order.shipments.reload
              end

              should_change("@order.state", :from => "canceled", :to => "paid") { @order.state }

              should "change all shipments to ready_to_ship" do
                assert @order.shipments.all?(&:ready_to_ship?)
              end
            end
          end

          context "and all shipments are shipped" do
            setup do
              shipment = @order.shipment.reload
              shipment.ship!
              @order.reload
            end

            should_change("@order.state", :from => "paid", :to => "shipped") { @order.state }

            context "and a return_authorization with all inventory_units returned" do
              setup do
                ra = ReturnAuthorization.new(:order => @order, :amount => 50.00)
                ra.add_variant(@order.line_items.first.variant_id, @order.line_items.first.quantity)
                ra.save!
                @order.reload
              end

              should_change("@order.state", :from => "shipped", :to => "awaiting_return") { @order.state }

              context "and received" do
                setup do
                  @order.return_authorizations.first.receive!
                  @order.reload
                end

                should_change("@order.state", :from => "awaiting_return", :to => "credit_owed") { @order.state }

                context "and a negative payment is created" do
                  setup do
                    @order.payments.create!(:amount => -50.00, :payment_method => Gateway.current)
                    #@creditcard.credit(50.00, @creditcard.authorization)
                    @order.reload
                  end

                  should_change("@order.state", :from => "credit_owed", :to => "returned") { @order.state }
                end

              end

            end

            context "and a return_authorization with not all inventory_units are returned is created" do
              setup do
                ra = ReturnAuthorization.new(:order => @order, :amount => 50.00)
                ra.add_variant(@order.line_items.first.variant_id, (@order.line_items.first.quantity - 1))
                ra.save!
                @order.reload
              end

              should_change("@order.state", :from => "shipped", :to => "awaiting_return") { @order.state }

              context "and received" do
                setup do
                  @order.return_authorizations.first.receive!
                  @order.reload
                end

                should_change("@order.state", :from => "awaiting_return", :to => "credit_owed") { @order.state }

                context "and a negative payment is created" do
                  setup do
                    @order.payments.create!(:amount => -50.00, :payment_method => Gateway.current)
                    @order.reload
                  end

                  should_change("@order.state", :from => "credit_owed", :to => "shipped") { @order.state }
                end

              end

            end

          end


          context "and an additional charge is added" do
            setup do
              @credit = Factory(:charge, :amount => 3.00, :order => @order)
              @order.update_totals!
              @order.reload
            end

            should_change("@order.state", :from => "paid", :to => "balance_due") { @order.state }

            context "and a payment is created" do
              setup do
                Factory(:payment, :payable => @order, :amount => 3.00)
              end

              should_change("@order.state", :from => "balance_due", :to => "paid") { @order.state }
            end

          end


          context "and an additional credit is added" do
            setup do
              @credit = Factory(:credit, :amount => 2.00, :order => @order)
              @order.update_totals!
              @order.reload
            end

            should_change("@order.state", :from => "paid", :to => "credit_owed") { @order.state }

            context "and a negative payment is created" do
              setup do
                @order.payments.create!(:amount => -2.00, :payment_method => Gateway.current)
                @order.update_totals!
                @order.reload
              end
              should_change("@order.state", :from => "credit_owed", :to => "paid") { @order.state }
            end

          end

        end


      end
  end
end