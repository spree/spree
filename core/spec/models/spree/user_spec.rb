require 'spec_helper'

describe Spree::LegacyUser do
  # Regression test for #2844 + #3346
  context "#last_incomplete_order" do
    let!(:user) { create(:user) }
    let!(:order) { create(:order, bill_address: create(:address), ship_address: create(:address)) }

    let!(:order_1) { create(:order, :created_at => 1.day.ago, :user => user, :created_by => user) }
    let!(:order_2) { create(:order, :user => user, :created_by => user) }
    let!(:order_3) { create(:order, :user => user, :created_by => create(:user)) }

    it "returns correct order" do
      user.last_incomplete_spree_order.should == order_2
    end

    context "persists order address" do
      it "copies over order addresses" do
        expect {
          user.persist_order_address(order)
        }.to change { Spree::Address.count }.by(2)

        expect(user.bill_address).to eq order.bill_address
        expect(user.ship_address).to eq order.ship_address
      end

      it "doesnt create new addresses if user has already" do
        user.update_column(:bill_address_id, create(:address))
        user.update_column(:ship_address_id, create(:address))
        user.reload

        expect {
          user.persist_order_address(order)
        }.not_to change { Spree::Address.count }
      end

      it "set both bill and ship address id on subject" do
        user.persist_order_address(order)

        expect(user.bill_address_id).not_to be_blank
        expect(user.ship_address_id).not_to be_blank
      end
    end
  end
end