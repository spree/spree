require 'spec_helper'

describe Spree::OrdersController, :type => :controller do
  let(:user) { create(:user) }

  context "Order model mock" do
    let(:order) do
      Spree::Order.create
    end

    before do
      allow(controller).to receive_messages(:try_spree_current_user => user)
    end

    context "#populate" do
      it "should create a new order when none specified" do
        spree_post :populate, {}, {}
        expect(cookies.signed[:guest_token]).not_to be_blank
        expect(Spree::Order.find_by_guest_token(cookies.signed[:guest_token])).to be_persisted
      end

      context "with Variant" do
        let(:populator) { double('OrderPopulator') }
        before do
          expect(Spree::OrderPopulator).to receive(:new).and_return(populator)
        end

        it "should handle population" do
          expect(populator).to receive(:populate).with(2, 5).and_return(true)
          spree_post(:populate, order_id: 1, variant_id: 2, quantity: 5)
          expect(response).to redirect_to(spree.cart_path)
        end

        it "shows an error when population fails" do
          request.env["HTTP_REFERER"] = spree.root_path
          expect(populator).to receive(:populate).with(2, 5).and_return(false)
          allow(populator).to receive_message_chain(:errors, :full_messages).and_return(['Order population failed'])
          spree_post(:populate, order_id: 1, variant_id: 2, quantity: 5)
          expect(flash[:error]).to eql('Order population failed')
          expect(response).to redirect_to(spree.root_path)
        end
      end
    end

    context "#update" do
      context "with authorization" do
        before do
          allow(controller).to receive :check_authorization
          allow(controller).to receive_messages current_order: order
        end

        it "should render the edit view (on failure)" do
          # email validation is only after address state
          order.update_column(:state, "delivery")
          spree_put :update, { :order => { :email => "" } }, { :order_id => order.id }
          expect(response).to render_template :edit
        end

        it "should redirect to cart path (on success)" do
          allow(order).to receive(:update_attributes).and_return true
          spree_put :update, {}, {:order_id => 1}
          expect(response).to redirect_to(spree.cart_path)
        end
      end
    end

    context "#empty" do
      before do
        allow(controller).to receive :check_authorization
      end

      it "should destroy line items in the current order" do
        allow(controller).to receive(:current_order).and_return(order)
        expect(order).to receive(:empty!)
        spree_put :empty
        expect(response).to redirect_to(spree.cart_path)
      end
    end

    # Regression test for #2750
    context "#update" do
      before do
        allow(user).to receive :last_incomplete_spree_order
        allow(controller).to receive :set_current_order
      end

      it "cannot update a blank order" do
        spree_put :update, :order => { :email => "foo" }
        expect(flash[:error]).to eq(Spree.t(:order_not_found))
        expect(response).to redirect_to(spree.root_path)
      end
    end
  end

  context "line items quantity is 0" do
    let(:order) { Spree::Order.create }
    let(:variant) { create(:variant) }
    let!(:line_item) { order.contents.add(variant, 1) }

    before do
      allow(controller).to receive(:check_authorization)
      allow(controller).to receive_messages(:current_order => order)
    end

    it "removes line items on update" do
      expect(order.line_items.count).to eq 1
      spree_put :update, :order => { line_items_attributes: { "0" => { id: line_item.id, quantity: 0 } } }
      expect(order.reload.line_items.count).to eq 0
    end
  end
end
