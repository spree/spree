require 'spec_helper'

describe Spree::LegacyUser, :type => :model do
  # Regression test for #2844 + #3346
  context "#last_incomplete_order" do
    let!(:user) { create(:user) }
    let!(:order) { create(:order, bill_address: create(:address), ship_address: create(:address)) }

    let!(:order_1) { create(:order, :created_at => 1.day.ago, :user => user, :created_by => user) }
    let!(:order_2) { create(:order, :user => user, :created_by => user) }
    let!(:order_3) { create(:order, :user => user, :created_by => create(:user)) }

    it "returns correct order" do
      expect(user.last_incomplete_spree_order).to eq order_3
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

    context "payment source" do
      let(:payment_method) { create(:credit_card_payment_method) }
      let!(:cc) do
        create(:credit_card, user_id: user.id, payment_method: payment_method, gateway_customer_profile_id: "2342343")
      end

      it "has payment sources" do
        expect(user.payment_sources.first.gateway_customer_profile_id).not_to be_empty
      end

      it "drops payment source" do
        user.drop_payment_source cc
        expect(cc.gateway_customer_profile_id).to be_nil
      end
    end
  end
end

describe Spree.user_class, :type => :model do
  context "reporting" do
    let(:order_value) { BigDecimal.new("80.94") }
    let(:order_count) { 4 }
    let(:orders) { Array.new(order_count, double(total: order_value)) }

    before do
      allow(orders).to receive(:pluck).with(:total).and_return(orders.map(&:total))
      allow(orders).to receive(:count).and_return(orders.length)
    end

    def load_orders
      allow(subject).to receive(:orders).and_return(double(complete: orders))
    end

    describe "#lifetime_value" do
      context "with orders" do
        before { load_orders }
        it "returns the total of completed orders for the user" do
          expect(subject.lifetime_value).to eq (order_count * order_value)
        end
      end
      context "without orders" do
        it "returns 0.00" do
          expect(subject.lifetime_value).to eq BigDecimal("0.00")
        end
      end
    end

    describe "#display_lifetime_value" do
      it "returns a Spree::Money version of lifetime_value" do
        value = BigDecimal("500.05")
        allow(subject).to receive(:lifetime_value).and_return(value)
        expect(subject.display_lifetime_value).to eq Spree::Money.new(value)
      end
    end

    describe "#order_count" do
      before { load_orders }
      it "returns the count of completed orders for the user" do
        expect(subject.order_count).to eq BigDecimal(order_count)
      end
    end

    describe "#average_order_value" do
      context "with orders" do
        before { load_orders }
        it "returns the average completed order price for the user" do
          expect(subject.average_order_value).to eq order_value
        end
      end
      context "without orders" do
        it "returns 0.00" do
          expect(subject.average_order_value).to eq BigDecimal("0.00")
        end
      end
    end

    describe "#display_average_order_value" do
      before { load_orders }
      it "returns a Spree::Money version of average_order_value" do
        value = BigDecimal("500.05")
        allow(subject).to receive(:average_order_value).and_return(value)
        expect(subject.display_average_order_value).to eq Spree::Money.new(value)
      end
    end
  end
end
