require 'spec_helper'

module Spree
  describe Spree::Api::PaymentsController do
    render_views
    let!(:order) { create(:order) }
    let!(:payment) { create(:payment, :order => order) }
    let!(:attributes) { [:id, :source_type, :source_id, :amount, :display_amount,
                         :payment_method_id, :response_code, :state, :avs_response,
                         :created_at, :updated_at] }

    let(:resource_scoping) { { :order_id => order.to_param } }

    before do
      stub_authentication!
    end

    context "as a user" do
      context "when the order belongs to the user" do
        before do
          Order.any_instance.stub :user => current_api_user
        end

        it "can view the payments for their order" do
          api_get :index
          json_response["payments"].first.should have_attributes(attributes)
        end

        it "can learn how to create a new payment" do
          api_get :new
          json_response["attributes"].should == attributes.map(&:to_s)
          json_response["payment_methods"].should_not be_empty
          json_response["payment_methods"].first.should have_attributes([:id, :name, :description])
        end

        it "can create a new payment" do
          api_post :create, :payment => { :payment_method_id => PaymentMethod.first.id, :amount => 50 }
          response.status.should == 201
          json_response.should have_attributes(attributes)
        end

        it "can view a pre-existing payment's details" do
          api_get :show, :id => payment.to_param
          json_response.should have_attributes(attributes)
        end

        it "cannot update a payment" do
          api_put :update, :id => payment.to_param, :payment => { :amount => 2.01 }
          assert_unauthorized!
        end

        it "cannot authorize a payment" do
          api_put :authorize, :id => payment.to_param
          assert_unauthorized!
        end
      end

      context "when the order does not belong to the user" do
        before do
          Order.any_instance.stub :user => stub_model(LegacyUser)
        end

        it "cannot view payments for somebody else's order" do
          api_get :index, :order_id => order.to_param
          assert_unauthorized!
        end
      end
    end

    context "as an admin" do
      sign_in_as_admin!

      it "can view the payments on any order" do
        api_get :index
        response.status.should == 200
        json_response["payments"].first.should have_attributes(attributes)
      end

      context "multiple payments" do
        before { @payment = create(:payment, :order => order, :response_code => '99999') }

        it "can view all payments on an order" do
          api_get :index
          json_response["count"].should == 2
        end

        it 'can control the page size through a parameter' do
          api_get :index, :per_page => 1
          json_response['count'].should == 1
          json_response['current_page'].should == 1
          json_response['pages'].should == 2
        end

        it 'can query the results through a paramter' do
          api_get :index, :q => { :response_code_cont => '999' }
          json_response['count'].should == 1
          json_response['payments'].first['response_code'].should eq @payment.response_code
        end
      end

      context "for a given payment" do
        context "updating" do
          it "can update" do
            payment.update_attributes(:state => 'pending')
            api_put :update, :id => payment.to_param, :payment => { :amount => 2.01 }
            response.status.should == 200
            payment.reload.amount.should == 2.01
          end

          context "update fails" do
            it "returns a 422 status when the amount is invalid" do
              payment.update_attributes(:state => 'pending')
              api_put :update, :id => payment.to_param, :payment => { :amount => 'invalid' }
              response.status.should == 422
              json_response["error"].should == "Invalid resource. Please fix errors and try again."
            end

            it "returns a 403 status when the payment is not pending" do
              payment.update_attributes(:state => 'completed')
              api_put :update, :id => payment.to_param, :payment => { :amount => 2.01 }
              response.status.should == 403
              json_response["error"].should == "This payment cannot be updated because it is completed."
            end
          end
        end

        context "authorizing" do
          it "can authorize" do
            api_put :authorize, :id => payment.to_param
            response.status.should == 200
            payment.reload.state.should == "pending"
          end

          context "authorization fails" do
            before do
              fake_response = double(:success? => false, :to_s => "Could not authorize card")
              Spree::Gateway::Bogus.any_instance.should_receive(:authorize).and_return(fake_response)
              api_put :authorize, :id => payment.to_param
            end

            it "returns a 422 status" do
              response.status.should == 422
              json_response["error"].should == "There was a problem with the payment gateway: Could not authorize card"
            end

            it "does not raise a stack level error" do
              pending "Investigate why a payment.reload after the request raises 'stack level too deep'"
              payment.reload.state.should == "failed"
            end
          end
        end

        context "capturing" do
          it "can capture" do
            api_put :capture, :id => payment.to_param
            response.status.should == 200
            payment.reload.state.should == "completed"
          end

          context "capturing fails" do
            before do
              fake_response = double(:success? => false, :to_s => "Insufficient funds")
              Spree::Gateway::Bogus.any_instance.should_receive(:capture).and_return(fake_response)
            end

            it "returns a 422 status" do
              api_put :capture, :id => payment.to_param
              response.status.should == 422
              json_response["error"].should == "There was a problem with the payment gateway: Insufficient funds"
            end
          end
        end

<<<<<<< HEAD
        it "returns a 422 status when purchasing fails" do
          fake_response = double(:success? => false, :to_s => "Insufficient funds")
          Spree::Gateway::Bogus.any_instance.should_receive(:purchase).and_return(fake_response)
          api_put :purchase, :id => payment.to_param
          response.status.should == 422
          json_response["error"].should == "There was a problem with the payment gateway: Insufficient funds"

          payment.reload
          payment.state.should == "failed"
=======
        context "purchasing" do
          it "can purchase" do
            api_put :purchase, :id => payment.to_param
            response.status.should == 200
            payment.reload.state.should == "completed"
          end

          context "purchasing fails" do
            before do
              fake_response = double(:success? => false, :to_s => "Insufficient funds")
              Spree::Gateway::Bogus.any_instance.should_receive(:purchase).and_return(fake_response)
            end

            it "returns a 422 status" do
              api_put :purchase, :id => payment.to_param
              response.status.should == 422
              json_response["error"].should == "There was a problem with the payment gateway: Insufficient funds"
            end
          end
>>>>>>> Refactor Spree::API::PaymentsController spec
        end

        context "voiding" do
          it "can void" do
            api_put :void, :id => payment.to_param
            response.status.should == 200
            payment.reload.state.should == "void"
          end

          context "voiding fails" do
            before do
              fake_response = double(:success? => false, :to_s => "NO REFUNDS")
              Spree::Gateway::Bogus.any_instance.should_receive(:void).and_return(fake_response)
            end

            it "returns a 422 status" do
              api_put :void, :id => payment.to_param
              response.status.should == 422
              json_response["error"].should == "There was a problem with the payment gateway: NO REFUNDS"

              payment.reload.state.should == "checkout"
            end
          end
        end

        context "crediting" do
          before do
            payment.purchase!
          end

          it "can credit" do
            api_put :credit, :id => payment.to_param
            response.status.should == 200
            payment.reload.state.should == "completed"

            # Ensure that a credit payment was created, and it has correct credit amount
            credit_payment = Payment.where(:source_type => 'Spree::Payment', :source_id => payment.id).last
            credit_payment.amount.to_f.should == -45.75
          end

          context "crediting fails" do
            it "returns a 422 status" do
              fake_response = double(:success? => false, :to_s => "NO CREDIT FOR YOU")
              Spree::Gateway::Bogus.any_instance.should_receive(:credit).and_return(fake_response)
              api_put :credit, :id => payment.to_param
              response.status.should == 422
              json_response["error"].should == "There was a problem with the payment gateway: NO CREDIT FOR YOU"
            end

            it "cannot credit over credit_allowed limit" do
              api_put :credit, :id => payment.to_param, :amount => 1000000
              response.status.should == 422
              json_response["error"].should == "This payment can only be credited up to 45.75. Please specify an amount less than or equal to this number."
            end
          end
        end
      end
    end
  end
end
