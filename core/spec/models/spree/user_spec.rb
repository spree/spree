require 'spec_helper'

describe Spree::LegacyUser, type: :model do # rubocop:disable RSpec/MultipleDescribes
  # Regression test for #2844 + #3346
  context '#last_incomplete_order' do
    let!(:user) { create(:user) }
    let!(:order) { create(:order, bill_address: create(:address), ship_address: create(:address)) }
    let(:store) { create :store }

    let(:order_1) { create(:order, created_at: 1.day.ago, user: user, created_by: user, store: store) }
    let(:order_2) { create(:order, user: user, created_by: user, store: store) }
    let(:order_3) { create(:order, user: user, created_by: create(:user), store: store) }

    it_behaves_like 'metadata', factory: :user

    it 'returns correct order' do
      Timecop.scale(3600) do
        order_1
        order_2
        order_3

        expect(user.last_incomplete_spree_order(store)).to eq order_3
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
    let!(:orders) { create_list(:order, order_count, user: subject, store: store, total: order_value, completed_at: Date.today, currency: currency) }
    let(:currency) { 'USD' }
    let(:store) { create :store }
    let(:order_value) { BigDecimal('80.94') }
    let(:order_count) { 4 }

    describe '#lifetime_value' do
      context 'with orders' do
        it 'returns the total of completed orders for the user' do
          expect(subject.lifetime_value(store: store, currency: currency)).to eq(order_count * order_value)
        end
      end

      context 'without orders' do
        let(:orders) {}

        it 'returns 0.00' do
          expect(subject.lifetime_value(store: store, currency: currency)).to eq BigDecimal('0.00')
        end
      end
    end

    describe '#display_lifetime_value' do
      it 'returns a Spree::Money version of lifetime_value' do
        expect(subject.display_lifetime_value(store: store, currency: currency).money.fractional).to eq(order_count * order_value * 100)
      end
    end

    describe '#order_count' do
      it 'returns the count of completed orders for the user' do
        expect(subject.order_count(store)).to eq order_count
      end
    end

    describe '#average_order_value' do
      context 'with orders' do
        it 'returns the average completed order price for the user' do
          expect(subject.average_order_value(store: store, currency: currency)).to eq order_value
        end
      end

      context 'without orders' do
        let(:orders) {}

        it 'returns 0.00' do
          expect(subject.average_order_value(store: store, currency: currency)).to eq BigDecimal('0.00')
        end
      end
    end

    describe '#display_average_order_value' do
      it 'returns a Spree::Money version of average_order_value' do
        value = BigDecimal('500.05')
        allow(subject).to receive(:average_order_value).and_return(value)
        expect(subject.display_average_order_value(store: store, currency: currency).money.fractional).to eq(value * 100)
      end
    end

    describe '#report_values_for' do
      context 'when order purchases in other currencies exist' do
        let(:eur_currency) { 'EUR' }
        let(:eur_order_value) { BigDecimal('12.34') }
        let(:eur_order_count) { 2 }

        before do
          create_list(:order, eur_order_count, user: subject, store: store, total: eur_order_value, completed_at: Date.today, currency: eur_currency)
        end

        context 'lifetime_value' do
          it 'returns a list of store lifetime values' do
            expect(subject.report_values_for(:lifetime_value, store)).to eq([Spree::Money.new((order_count * order_value), currency: currency),
                                                                             Spree::Money.new((eur_order_count * eur_order_value), currency: eur_currency)])
          end
        end

        context 'average_order_value' do
          context 'with orders' do
            it 'returns a list of average completed order prices for the user' do
              expect(subject.report_values_for(:average_order_value, store)).to eq([Spree::Money.new((order_value), currency: currency),
                                                                                    Spree::Money.new((eur_order_value), currency: eur_currency)])
            end
          end
        end
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
      subject { user }

      let!(:store) { create(:store, default: true) }
      let!(:user) { create(:user) }
      let(:amount) { 120.25 }
      let(:additional_amount) { 55.75 }
      let!(:store_credit) { create(:store_credit, user: user, amount: amount, amount_used: 0.0, store: store) }
      let!(:additional_store_credit) { create(:store_credit, user: user, amount: additional_amount, amount_used: 0.0, store: store) }

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

  describe '#available_store_credits' do
    let(:store) { create(:store) }

    context 'user does not have any associated store credits' do
      subject { create(:user) }

      it 'returns empty array' do
        expect(subject.available_store_credits(store)).to be_empty
      end
    end

    context 'user has several associated store credits' do
      subject { store_credit.user }

      let(:user) { create(:user) }
      let(:usd_amount) { 120.25 }
      let(:additional_amount) { 55.75 }
      let(:store_credit) { create(:store_credit, user: user, amount: usd_amount, amount_used: 0.0, store: store) }

      context 'store credits have never been used' do
        it 'returns store credit amount' do
          expect(subject.available_store_credits(store)).to eq([Spree::Money.new(usd_amount, currency: 'USD')])
        end
      end

      context 'store credits in different currencies exits' do
        let(:gbp_amount) { '123.12' }
        let(:eur_amount) { '321.31' }

        before do
          create(:store_credit, user: user, amount: gbp_amount, amount_used: 0.0, store: store, currency: 'GBP')
          create(:store_credit, user: user, amount: eur_amount, amount_used: 0.0, store: store, currency: 'EUR')
        end

        it 'returns sum of amounts' do
          expect(subject.available_store_credits(store)).to match_array([Spree::Money.new(usd_amount, currency: 'USD'),
                                                                         Spree::Money.new(gbp_amount, currency: 'GBP'),
                                                                         Spree::Money.new(eur_amount, currency: 'EUR')])
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

  describe 'validations' do
    shared_examples 'valid' do
      it 'is valid' do
        expect(subject.valid?).to be true
      end
    end

    describe '#address_not_associated_with_other_user' do
      subject { user }

      let!(:user) { create(:user_with_addresses) }
      let!(:other_user) { create(:user_with_addresses) }
      let(:bill_address) { create(:address, user: assigned_user) }
      let(:ship_address) { create(:address, user: assigned_user) }

      shared_examples 'invalid' do
        it 'is invalid' do
          expect(subject.valid?).to be false
          expect(subject.errors.messages.values.flatten).to include('belongs to other user')
        end
      end

      context 'bill_address' do
        before { subject.update(bill_address: bill_address) }

        context 'when default bill address does not belong to any user' do
          let(:assigned_user) { nil }

          it_should_behave_like 'valid'
        end

        context 'when default bill address belongs to user' do
          let(:assigned_user) { user }

          it_should_behave_like 'valid'
        end

        context 'when associated bill address belongs to other user' do
          let(:assigned_user) { other_user }

          it_should_behave_like 'invalid'

          it 'assigns error to bill address' do
            expect(subject.errors.messages.keys).to include(:bill_address_id)
          end
        end
      end

      context 'ship_address' do
        before { subject.update(ship_address: ship_address) }

        context 'when default ship address does not belong to any user' do
          let(:assigned_user) { nil }

          it_should_behave_like 'valid'
        end

        context 'when default ship address belongs to user' do
          let(:assigned_user) { user }

          it_should_behave_like 'valid'
        end

        context 'when associated ship address belongs to other user' do
          let(:assigned_user) { other_user }

          it_should_behave_like 'invalid'

          it 'assigns error to ship address' do
            expect(subject.errors.messages.keys).to include(:ship_address_id)
          end
        end
      end
    end

    describe '#address_not_deprecated_in_completed_order' do
      subject { user }

      let!(:user) { create(:user_with_addresses) }
      let(:address) { create(:address, user: user) }

      shared_examples 'invalid' do
        it 'is invalid' do
          expect(subject.valid?).to be false
          expect(subject.errors.messages.values.flatten).to include('deprecated in completed order')
        end
      end

      context 'bill_address' do
        before { subject.update(bill_address: address) }

        context 'when default bill address is not associated to completed order' do
          let!(:completed_order) { create(:completed_order_with_totals, user: user) }

          it_should_behave_like 'valid'
        end

        context 'when default bill address is associated to uncompleted order' do
          let!(:uncompleted_order) { create(:order, user: user, bill_address: address, ship_address: address) }

          it_should_behave_like 'valid'
        end

        context 'when default bill address is associated to completed order' do
          let!(:completed_order) { create(:completed_order_with_totals, user: user, bill_address: address, ship_address: address) }

          context 'when default bill address is the same as associated to order' do
            it { expect(user.addresses).to include(address) }

            it_should_behave_like 'valid'
          end

          context 'when user changed bill address which was used in completed order so the old one is deprecated' do
            before { address.update(deleted_at: Time.now) }

            it { expect(user.addresses).not_to include(address) }

            it_should_behave_like 'invalid'

            it 'assigns error to bill address' do
              expect(subject.valid?).to be false
              expect(subject.errors.messages.keys).to include(:bill_address_id)
            end
          end
        end
      end

      context 'ship_address' do
        before { subject.update(ship_address: address) }

        context 'when default ship address is not associated to completed order' do
          let!(:completed_order) { create(:completed_order_with_totals, user: user) }

          it_should_behave_like 'valid'
        end

        context 'when default ship address is associated to uncompleted order' do
          let!(:uncompleted_order) { create(:order, user: user, ship_address: address) }

          it_should_behave_like 'valid'
        end

        context 'when default ship address is associated to completed order' do
          let!(:completed_order) { create(:completed_order_with_totals, user: user, bill_address: address, ship_address: address) }

          context 'when default ship address is the same as associated to order' do
            it { expect(user.addresses).to include(address) }

            it_should_behave_like 'valid'
          end

          context 'when user changed ship address which was used in completed order so the old one is deprecated' do
            before { address.update(deleted_at: Time.now) }

            it { expect(user.addresses).not_to include(address) }

            it_should_behave_like 'invalid'

            it 'assigns error to ship address' do
              expect(subject.valid?).to be false
              expect(subject.errors.messages.keys).to include(:ship_address_id)
            end
          end
        end
      end
    end
  end
end
