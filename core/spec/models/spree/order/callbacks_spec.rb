require 'spec_helper'

describe Spree::Order, type: :model do
  let(:order) { stub_model(Spree::Order) }

  before do
    Spree::Order.define_state_machine!
  end

  context 'validations' do
    context 'email validation' do
      # Regression test for #1238
      it "o'brien@gmail.com is a valid email address" do
        order.state = 'address'
        order.email = "o'brien@gmail.com"
        order.valid?
        expect(order.errors).to be_empty
      end
    end
  end

  context '#save' do
    context 'when associated with a registered user' do
      let(:user) { double(:user, email: 'test@example.com') }

      before do
        allow(order).to receive_messages user: user
      end

      it 'assigns the email address of the user' do
        order.run_callbacks(:create)
        expect(order.email).to eq(user.email)
      end
    end
  end

  context 'in the cart state' do
    it 'does not validate email address' do
      order.state = 'cart'
      order.email = nil
      order.valid?
      expect(order.errors).to be_empty
    end
  end
end
