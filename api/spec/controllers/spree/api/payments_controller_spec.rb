require 'spec_helper'

module Spree
  describe Spree::Api::PaymentsController, :type => :controller do
    render_views
    let!(:order) { create(:order) }
    let!(:payment) { create(:payment, :order => order) }
    let!(:attributes) { [:id, :source_type, :source_id, :amount, :display_amount,
                         :payment_method_id, :state, :avs_response,
                         :created_at, :updated_at] }

    let(:resource_scoping) { { :order_id => order.to_param } }

    before do
      stub_authentication!
    end

    context "as a user" do
      context "when the order belongs to the user" do
        before do
          allow_any_instance_of(Order).to receive_messages :user => current_api_user
        end

        it "can view the payments for their order" do
          api_get :index
          expect(json_response["payments"].first).to have_attributes(attributes)
        end

        it "can learn how to create a new payment" do
          api_get :new
          expect(json_response["attributes"]).to eq(attributes.map(&:to_s))
          expect(json_response["payment_methods"]).not_to be_empty
          expect(json_response["payment_methods"].first).to have_attributes([:id, :name, :description])
        end

        it "can create a new payment" do
          api_post :create, :payment => { :payment_method_id => PaymentMethod.first.id, :amount => 50 }
          expect(response.status).to eq(201)
          expect(json_response).to have_attributes(attributes)
        end

        it "can view a pre-existing payment's details" do
          api_get :show, :id => payment.to_param
          expect(json_response).to have_attributes(attributes)
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
          allow_any_instance_of(Order).to receive_messages :user => stub_model(LegacyUser)
        end

        it "cannot view payments for somebody else's order" do
          api_get :index, :order_id => order.to_param
          assert_unauthorized!
        end

        it "can view the payments for an order given the order token" do
          api_get :index, :order_id => order.to_param, :order_token => order.guest_token
          expect(json_response["payments"].first).to have_attributes(attributes)
        end
      end
    end

    context "as an admin" do
      sign_in_as_admin!

      it "can view the payments on any order" do
        api_get :index
        expect(response.status).to eq(200)
        expect(json_response["payments"].first).to have_attributes(attributes)
      end

      context "multiple payments" do
        before { @payment = create(:payment, :order => order) }

        it "can view all payments on an order" do
          api_get :index
          expect(json_response["count"]).to eq(2)
        end

        it 'can control the page size through a parameter' do
          api_get :index, :per_page => 1
          expect(json_response['count']).to eq(1)
          expect(json_response['current_page']).to eq(1)
          expect(json_response['pages']).to eq(2)
        end
      end

      context "for a given payment" do
        context "updating" do
          context "when the state is checkout" do
            it "can update" do
              payment.update_attributes(state: 'checkout')
              api_put(:update, id: payment.to_param, payment: { amount: 2.01 })
              expect(response.status).to be(200)
              expect(payment.reload.amount).to eq(2.01)
            end
          end

          context "when the state is pending" do
            it "can update" do
              payment.update_attributes(state: 'pending')
              api_put(:update, id: payment.to_param, payment: { amount: 2.01 })
              expect(response.status).to be(200)
              expect(payment.reload.amount).to eq(2.01)
            end
          end

          context "update fails" do
            it "returns a 422 status when the amount is invalid" do
              payment.update_attributes(state: 'pending')
              api_put(:update, id: payment.to_param, payment: { amount: 'invalid' })
              expect(response.status).to be(422)
              expect(json_response['error']).to eql('Invalid resource. Please fix errors and try again.')
            end

            it "returns a 403 status when the payment is not pending" do
              payment.update_attributes(state: 'completed')
              api_put(:update, id: payment.to_param, payment: { amount: 2.01 })
              expect(response.status).to be(403)
              expect(json_response['error']).to eql('This payment cannot be updated because it is completed.')
            end
          end
        end

        context "authorizing" do
          it "can authorize" do
            api_put :authorize, :id => payment.to_param
            expect(response.status).to eq(200)
            expect(payment.reload.state).to eq("pending")
          end

          context "authorization fails" do
            before do
              fake_response = double(:success? => false, :to_s => "Could not authorize card")
              expect_any_instance_of(Spree::Gateway::Bogus).to receive(:authorize).and_return(fake_response)
              api_put :authorize, :id => payment.to_param
            end

            it "returns a 422 status" do
              expect(response.status).to eq(422)
              expect(json_response["error"]).to eq "Invalid resource. Please fix errors and try again."
              expect(json_response["errors"]["base"][0]).to eq "Could not authorize card"
            end

            it "does not raise a stack level error" do
              skip "Investigate why a payment.reload after the request raises 'stack level too deep'"
              expect(payment.reload.state).to eq("failed")
            end
          end
        end

        context "capturing" do
          it "can capture" do
            api_put :capture, :id => payment.to_param
            expect(response.status).to eq(200)
            expect(payment.reload.state).to eq("completed")
          end

          context "capturing fails" do
            before do
              fake_response = double(:success? => false, :to_s => "Insufficient funds")
              expect_any_instance_of(Spree::Gateway::Bogus).to receive(:capture).and_return(fake_response)
            end

            it "returns a 422 status" do
              api_put :capture, :id => payment.to_param
              expect(response.status).to eq(422)
              expect(json_response["error"]).to eq "Invalid resource. Please fix errors and try again."
              expect(json_response["errors"]["base"][0]).to eq "Insufficient funds"
            end
          end
        end

        context "purchasing" do
          it "can purchase" do
            api_put :purchase, :id => payment.to_param
            expect(response.status).to eq(200)
            expect(payment.reload.state).to eq("completed")
          end

          context "purchasing fails" do
            before do
              fake_response = double(:success? => false, :to_s => "Insufficient funds")
              expect_any_instance_of(Spree::Gateway::Bogus).to receive(:purchase).and_return(fake_response)
            end

            it "returns a 422 status" do
              api_put :purchase, :id => payment.to_param
              expect(response.status).to eq(422)
              expect(json_response["error"]).to eq "Invalid resource. Please fix errors and try again."
              expect(json_response["errors"]["base"][0]).to eq "Insufficient funds"
            end
          end
        end

        context "voiding" do
          it "can void" do
            api_put :void, id: payment.to_param
            expect(response.status).to eq 200
            expect(payment.reload.state).to eq "void"
          end

          context "voiding fails" do
            before do
              fake_response = double(success?: false, to_s: "NO REFUNDS")
              expect_any_instance_of(Spree::Gateway::Bogus).to receive(:void).and_return(fake_response)
            end

            it "returns a 422 status" do
              api_put :void, id: payment.to_param
              expect(response.status).to eq 422
              expect(json_response["error"]).to eq "Invalid resource. Please fix errors and try again."
              expect(json_response["errors"]["base"][0]).to eq "NO REFUNDS"
              expect(payment.reload.state).to eq "checkout"
            end
          end
        end

      end
    end
  end
end
