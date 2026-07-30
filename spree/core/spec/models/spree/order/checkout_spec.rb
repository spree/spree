require 'spec_helper'

describe Spree::Order, type: :model do
  let!(:store) { @default_store }
  let(:order) { build(:order, store: store, accept_marketing: accept_marketing) }
  let(:country) { store.default_country || create(:country_us) }
  let(:accept_marketing) { false }
  let!(:state) { country.states.first || create(:state, country: country, name: 'New York', abbr: 'NY') }

  describe '#checkout_steps' do
    context 'when confirmation not required' do
      before do
        allow(order).to receive_messages confirmation_required?: false
        allow(order).to receive_messages payment_required?: true
      end

      specify do
        expect(order.checkout_steps).to eq(%w(address delivery payment complete))
      end
    end

    context 'when confirmation required' do
      before do
        allow(order).to receive_messages confirmation_required?: true
        allow(order).to receive_messages payment_required?: true
      end

      specify do
        expect(order.checkout_steps).to eq(%w(address delivery payment confirm complete))
      end
    end

    context 'when delivery not required' do
      before { allow(order).to receive_messages delivery_required?: false }

      specify do
        expect(order.checkout_steps).to eq(%w(address complete))
      end
    end

    context 'when payment not required' do
      before { allow(order).to receive_messages payment_required?: false }

      specify do
        expect(order.checkout_steps).to eq(%w(address delivery complete))
      end
    end

    context 'when payment required' do
      before { allow(order).to receive_messages payment_required?: true }

      specify do
        expect(order.checkout_steps).to eq(%w(address delivery payment complete))
      end
    end
  end

  describe '#checkout_step_index' do
    it 'always returns an integer' do
      expect(order.checkout_step_index('imnotthere')).to be_a Integer
      expect(order.checkout_step_index('delivery')).to be > 0
    end
  end

  describe '#assign_default_addresses!' do
    let(:default_address) { create(:address, state: state) }
    let(:order) { create(:order, store: store, ship_address: nil, bill_address: nil, user: user) }

    shared_examples 'it cloned the default address' do
      it do
        order.assign_default_addresses!
        order.save!
        order.reload

        default_attributes = default_address.attributes
        order_attributes = order.send("#{address_kind}_address".to_sym).try(:attributes) || {}
        expect(order_attributes.except('id', 'created_at', 'updated_at')).to eql(default_attributes.except('id', 'created_at', 'updated_at'))
      end
    end

    it_behaves_like 'it cloned the default address' do
      let(:user) { create(:user, ship_address: default_address) }
      let(:address_kind) { 'ship' }
    end

    it_behaves_like 'it cloned the default address' do
      let(:user) { create(:user, bill_address: default_address) }
      let(:address_kind) { 'bill' }
    end

    it "doesn't raise an error if the default address is invalid" do
      order = create(:order, store: store, ship_address: nil, bill_address: nil)
      order.user = build(:user, ship_address: build(:address, city: nil), bill_address: build(:address, city: nil))

      expect { order.assign_default_addresses! }.not_to raise_error
    end
  end

  describe 'completion side effects' do
    let(:order) do
      create(:order_with_line_items, store: store, user: user, email: email, accept_marketing: accept_marketing)
    end
    let(:user) { create(:user) }
    let(:email) { user.email }

    describe 'newsletter subscription' do
      context 'when newsletter is accepted for the order' do
        let(:accept_marketing) { true }

        it 'subscribes to newsletter' do
          expect(Spree::NewsletterSubscriber).to receive(:subscribe).with(email: order.email, user: order.user, store: order.store)
          order.finalize!
        end
      end

      context 'when newsletter is not accepted for the order' do
        let(:accept_marketing) { false }

        it 'does not subscribe to newsletter' do
          expect(Spree::NewsletterSubscriber).not_to receive(:subscribe)
          order.finalize!
        end
      end
    end

    context 'when gift card is present' do
      let(:gift_card) { create(:gift_card, amount: order.total, store: store) }

      before do
        order.recalculate_totals!
        order.apply_gift_card(gift_card)
      end

      it 'redeems the gift card' do
        expect(gift_card.redeemed_at).to be_nil
        expect { order.finalize! }.to change { gift_card.reload.state }.from('active').to('redeemed')
        expect(gift_card.amount_used).to eq(order.total)
        expect(gift_card.amount_remaining).to eq(0)
        expect(gift_card.redeemed_at).to be_present
      end

      context 'when gift card has amount bigger than order total' do
        let(:gift_card) { create(:gift_card, amount: order.total + 1, store: store) }

        it 'partially redeems the gift card' do
          expect { order.finalize! }.to change { gift_card.reload.state }.from('active').to('partially_redeemed')
          expect(gift_card.amount_used).to eq(order.total)
          expect(gift_card.amount_remaining).to eq(1)
          expect(gift_card.redeemed_at).to be_nil
        end
      end
    end

    context 'when user is not present' do
      let(:user) { nil }
      let(:email) { 'new@customer.com' }

      context 'with signup_for_an_account set to true' do
        before do
          allow(order).to receive(:signup_for_an_account?).and_return(true)
        end

        it 'creates a new user' do
          expect { order.finalize! }.to change { Spree.user_class.count }.by(1)
          expect(order.user).to be_present
          expect(order.user.email).to eq(order.email)
        end
      end

      context 'with signup_for_an_account set to false' do
        before do
          allow(order).to receive(:signup_for_an_account?).and_return(false)
        end

        it 'does not create a new user' do
          expect { order.finalize! }.not_to change { Spree.user_class.count }
        end
      end
    end
  end
end
