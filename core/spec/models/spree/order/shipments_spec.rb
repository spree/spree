describe Spree::Order, :type => :model do
  let(:order) { stub_model(Spree::Order) }

  context "ensure shipments will be updated" do
    before { Spree::Shipment.create!(order: order) }

    it "destroys current shipments" do
      order.ensure_updated_shipments
      expect(order.shipments).to be_empty
    end

    it "puts order back in address state" do
      order.ensure_updated_shipments
      expect(order.state).to eql "address"
    end

    it "resets shipment_total" do
      order.update_column(:shipment_total, 5)
      order.ensure_updated_shipments
      expect(order.shipment_total).to eq(0)
    end

    context "except when order is completed, that's OrderInventory job" do
      it "doesn't touch anything" do
        allow(order).to receive_messages completed?: true
        order.update_column(:shipment_total, 5)
        order.shipments.create!

        expect {
          order.ensure_updated_shipments
        }.not_to change { order.shipment_total }

        expect {
          order.ensure_updated_shipments
        }.not_to change { order.shipments }

        expect {
          order.ensure_updated_shipments
        }.not_to change { order.state }
      end
    end
  end
end
