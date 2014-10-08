require 'spec_helper'

describe Spree::Api::ShipmentsController do
  render_views
  let!(:shipment) { create(:shipment) }
  let!(:attributes) { [:id, :tracking, :number, :cost, :shipped_at, :stock_location_name, :order_id, :shipping_rates, :shipping_methods] }

  before do
    stub_authentication!
  end

  let!(:resource_scoping) { { id: shipment.to_param, shipment: { order_id: shipment.order.to_param } } }

  context "as a non-admin" do
    it "cannot make a shipment ready" do
      api_put :ready
      assert_not_found!
    end

    it "cannot make a shipment shipped" do
      api_put :ship
      assert_not_found!
    end
  end

  context "as an admin" do
    let!(:order) { shipment.order }
    let!(:stock_location) { create(:stock_location_with_items) }
    let!(:variant) { create(:variant) }

    sign_in_as_admin!

    # Start writing this spec a bit differently than before....
    describe 'POST #create' do
      let(:params) do
        {
          variant_id: stock_location.stock_items.first.variant.to_param,
          shipment: { order_id: order.number },
          stock_location_id: stock_location.to_param
        }
      end 
      
      subject do 
        api_post :create, params
      end

      [:variant_id, :stock_location_id].each do |field|
        context "when #{field} is missing" do
          before do
            params.delete(field)
          end

          it 'should return proper error' do
            subject
            expect(response.status).to eq(422)
            expect(json_response['exception']).to eq("param is missing or the value is empty: #{field.to_s}")
          end
        end
      end

      it 'should create a new shipment' do
        expect(subject).to be_ok
        expect(json_response).to have_attributes(attributes)
      end
    end

    it 'can update a shipment' do
      params = {
        shipment: {
          stock_location_id: stock_location.to_param
        }
      }

      api_put :update, params
      response.status.should == 200
      json_response['stock_location_name'].should == stock_location.name
    end

    it "can make a shipment ready" do
      Spree::Order.any_instance.stub(:paid? => true, :complete? => true)
      api_put :ready
      json_response.should have_attributes(attributes)
      json_response["state"].should == "ready"
      shipment.reload.state.should == "ready"
    end

    it "cannot make a shipment ready if the order is unpaid" do
      Spree::Order.any_instance.stub(:paid? => false)
      api_put :ready
      json_response["error"].should == "Cannot ready shipment."
      response.status.should == 422
    end

    context 'for completed shipments' do
      let(:order) { create :completed_order_with_totals }
      let!(:resource_scoping) { { id: order.shipments.first.to_param, shipment: { order_id: order.to_param } } }

      it 'adds a variant to a shipment' do
        api_put :add, { variant_id: variant.to_param, quantity: 2 }
        response.status.should == 200
        json_response['manifest'].detect { |h| h['variant']['id'] == variant.id }["quantity"].should == 2
      end

      it 'removes a variant from a shipment' do
        order.contents.add(variant, 2)

        api_put :remove, { variant_id: variant.to_param, quantity: 1 }
        response.status.should == 200
        json_response['manifest'].detect { |h| h['variant']['id'] == variant.id }["quantity"].should == 1
      end

      it 'removes a destroyed variant from a shipment' do
        order.contents.add(variant, 2)
        variant.destroy

        api_put :remove, { variant_id: variant.to_param, quantity: 1 }
        response.status.should == 200
        json_response['manifest'].detect { |h| h['variant']['id'] == variant.id }["quantity"].should == 1
      end
    end

    context "can transition a shipment from ready to ship" do
      before do
        Spree::Order.any_instance.stub(:paid? => true, :complete? => true)
        # For the shipment notification email
        Spree::Config[:mails_from] = "spree@example.com"

        shipment.update!(shipment.order)
        shipment.state.should == "ready"
        Spree::ShippingRate.any_instance.stub(:cost => 5)
      end

      it "can transition a shipment from ready to ship" do
        shipment.reload
        api_put :ship, id: shipment.to_param, shipment: { tracking: "123123", order_id: shipment.order.to_param }
        json_response.should have_attributes(attributes)
        json_response["state"].should == "shipped"
      end

    end

    describe '#mine' do
      subject do
        api_get :mine, format: 'json', params: params
      end

      let(:params) { {} }

      before { subject }

      context "the current api user is authenticated and has orders" do
        let(:current_api_user) { shipped_order.user }
        let(:shipped_order) { create(:shipped_order) }

        it 'succeeds' do
          expect(response.status).to eq 200
        end

        describe 'json output' do
          render_views

          let(:rendered_shipment_ids) { json_response['shipments'].map { |s| s['id'] } }

          it 'contains the shipments' do
            expect(rendered_shipment_ids).to match_array current_api_user.orders.flat_map(&:shipments).map(&:id)
          end
        end

        context 'with filtering' do
          let(:params) { {q: {order_completed_at_not_null: 1}} }

          let!(:incomplete_order) { create(:order, user: current_api_user) }

          it 'filters' do
            expect(assigns(:shipments).map(&:id)).to match_array current_api_user.orders.complete.flat_map(&:shipments).map(&:id)
          end
        end
      end

      context "the current api user is not persisted" do
        let(:current_api_user) { Spree.user_class.new }

        it "returns a 401" do
          response.status.should == 401
        end
      end
    end

  end
end
