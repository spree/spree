require 'spec_helper'

describe Spree::LegacyUser, type: :model do # rubocop:disable RSpec/MultipleDescribes
  # Regression test for #2844 + #3346
  context '#last_incomplete_order' do
    let!(:user) { create(:user) }
    let!(:order) { create(:order, bill_address: create(:address), ship_address: create(:address)) }
    let(:current_store) { create :store }

    let(:order_1) { create(:order, created_at: 1.day.ago, user: user, created_by: user, store: current_store) }
    let(:order_2) { create(:order, user: user, created_by: user, store: current_store) }
    let(:order_3) { create(:order, user: user, created_by: create(:user), store: current_store) }

    it 'returns correct order' do
      Timecop.scale(3600) do
        order_1
        order_2
        order_3

        expect(user.last_incomplete_spree_order(current_store)).to eq order_3
      end
    end

    context 'persists order address' do
      it 'copies over order addresses' do
        expect do
          user.persist_order_address(order)
        end.to change { Spree::Address.count }.by(2)

        expect(user.bill_address).to eq order.bill_address
        expect(user.ship_address).to eq order.ship_address
      end

      it 'doesnt create new addresses if user has already' do
        user.update_column(:bill_address_id, create(:address).id)
        user.update_column(:ship_address_id, create(:address).id)
        user.reload

        expect do
          user.persist_order_address(order)
        end.not_to change { Spree::Address.count }
      end

      it 'set both bill and ship address id on subject' do
        user.persist_order_address(order)

        expect(user.bill_address_id).not_to be_blank
        expect(user.ship_address_id).not_to be_blank
      end
    end

    context 'payment source' do
      let(:payment_method) { create(:credit_card_payment_method) }
      let!(:cc) do
        create(:credit_card, user_id: user.id, payment_method: payment_method, gateway_customer_profile_id: '2342343')
      end

      it 'has payment sources' do
        expect(user.payment_sources.first.gateway_customer_profile_id).not_to be_empty
      end

      it 'drops payment source' do
        user.drop_payment_source cc
        expect(cc.gateway_customer_profile_id).to be_nil
      end
    end
  end
end

describe Spree.user_class, type: :model do
  context 'reporting' do
    let(:order_value) { BigDecimal('80.94') }
    let(:order_count) { 4 }
    let(:orders) { Array.new(order_count, double(total: order_value)) }

    before do
      allow(orders).to receive(:sum).with(:total).and_return(orders.sum(&:total))
      allow(orders).to receive(:count).and_return(orders.length)
    end

    def load_orders
      allow(subject).to receive(:orders).and_return(double(complete: orders))
    end

    describe '#lifetime_value' do
      context 'with orders' do
        before { load_orders }

        it 'returns the total of completed orders for the user' do
          expect(subject.lifetime_value).to eq (order_count * order_value)
        end
      end

      context 'without orders' do
        it 'returns 0.00' do
          expect(subject.lifetime_value).to eq BigDecimal('0.00')
        end
      end
    end

    describe '#display_lifetime_value' do
      it 'returns a Spree::Money version of lifetime_value' do
        value = BigDecimal('500.05')
        allow(subject).to receive(:lifetime_value).and_return(value)
        expect(subject.display_lifetime_value).to eq Spree::Money.new(value)
      end
    end

    describe '#order_count' do
      before { load_orders }

      it 'returns the count of completed orders for the user' do
        expect(subject.order_count).to eq order_count
      end
    end

    describe '#average_order_value' do
      context 'with orders' do
        before { load_orders }

        it 'returns the average completed order price for the user' do
          expect(subject.average_order_value).to eq order_value
        end
      end

      context 'without orders' do
        it 'returns 0.00' do
          expect(subject.average_order_value).to eq BigDecimal('0.00')
        end
      end
    end

    describe '#display_average_order_value' do
      before { load_orders }

      it 'returns a Spree::Money version of average_order_value' do
        value = BigDecimal('500.05')
        allow(subject).to receive(:average_order_value).and_return(value)
        expect(subject.display_average_order_value).to eq Spree::Money.new(value)
      end
    end
  end

  describe '#total_available_store_credit' do
    context 'user does not have any associated store credits' do
      subject { create(:user) }

      it 'returns 0' do
        expect(subject.total_available_store_credit).to be_zero
      end
    end

    context 'user has several associated store credits' do
      subject { store_credit.user }

      let(:user) { create(:user) }
      let(:amount) { 120.25 }
      let(:additional_amount) { 55.75 }
      let(:store_credit) { create(:store_credit, user: user, amount: amount, amount_used: 0.0) }
      let!(:additional_store_credit) { create(:store_credit, user: user, amount: additional_amount, amount_used: 0.0) }

      context 'part of the store credit has been used' do
        let(:amount_used) { 35.00 }

        before { store_credit.update(amount_used: amount_used) }

        context 'part of the store credit has been authorized' do
          let(:authorized_amount) { 10 }

          before { additional_store_credit.update(amount_authorized: authorized_amount) }

          it 'returns sum of amounts minus used amount and authorized amount' do
            available_store_credit = amount + additional_amount - amount_used - authorized_amount
            expect(subject.total_available_store_credit.to_f).to eq available_store_credit
          end
        end

        context 'there are no authorized amounts on any of the store credits' do
          it 'returns sum of amounts minus used amount' do
            expect(subject.total_available_store_credit.to_f).to eq (amount + additional_amount - amount_used)
          end
        end
      end

      context 'store credits have never been used' do
        context 'part of the store credit has been authorized' do
          let(:authorized_amount) { 10 }

          before { additional_store_credit.update(amount_authorized: authorized_amount) }

          it 'returns sum of amounts minus authorized amount' do
            expect(subject.total_available_store_credit.to_f).to eq (amount + additional_amount - authorized_amount)
          end
        end

        context 'there are no authorized amounts on any of the store credits' do
          it 'returns sum of amounts' do
            expect(subject.total_available_store_credit.to_f).to eq (amount + additional_amount)
          end
        end
      end

      context 'all store credits have never been used or authorized' do
        it 'returns sum of amounts' do
          expect(subject.total_available_store_credit.to_f).to eq (amount + additional_amount)
        end
      end
    end
  end

  context 'address book' do
    let(:address) { create(:address) }
    let(:address2) { create(:address) }

    before do
      address.user = subject
      address.save
      address2.user = subject
      address2.save
    end

    it 'has many addresses' do
      expect(subject).to respond_to(:addresses)
      expect(subject.addresses).to eq [address2, address]
    end
  end
end
