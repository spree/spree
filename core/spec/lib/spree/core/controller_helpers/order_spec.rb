require 'spec_helper'

class FakesController < ApplicationController
  include Spree::Core::ControllerHelpers::Order
end

describe Spree::Core::ControllerHelpers::Order, type: :controller do
  controller(FakesController) {}

  let(:user) { create(:user) }
  let(:order) { create(:order, user: user) }
  let(:store) { create(:store) }

  describe '#simple_current_order' do
    before { controller.stub(try_spree_current_user: user) }
    it 'returns nil' do
      expect(controller.simple_current_order).to be_nil
    end
    it 'returns Spree::Order instance' do
      controller.stub(cookies: double(signed: { guest_token: order.guest_token }))
      expect(controller.simple_current_order).to eq order
    end
  end

  describe '#current_order' do
    before {
      Spree::Order.destroy_all # TODO data is leaking between specs as database_cleaner or rspec 3 was broken in Rails 4.1.6 & 4.0.10
      controller.stub(current_store: store)
      controller.stub(try_spree_current_user: user)
    }
    context 'create_order_if_necessary option is false' do
      let!(:order) { create :order, user: user }
      it 'returns current order' do
        expect(controller.current_order).to eq order
      end
    end
    context 'create_order_if_necessary option is true' do
      it 'creates new order' do
        expect {
          controller.current_order(create_order_if_necessary: true)
        }.to change(Spree::Order, :count).to(1)
      end

      it 'assigns the current_store id' do
        controller.current_order(create_order_if_necessary: true)
        expect(Spree::Order.last.store_id).to eq store.id
      end
    end
  end

  describe '#associate_user' do
    before do
      controller.stub(current_order: order, try_spree_current_user: user)
    end
    context "user's email is blank" do
      let(:user) { create(:user, email: '') }
      it 'calls Spree::Order#associate_user! method' do
        Spree::Order.any_instance.should_receive(:associate_user!)
        controller.associate_user
      end
    end
    context "user isn't blank" do
      it 'does not calls Spree::Order#associate_user! method' do
        Spree::Order.any_instance.should_not_receive(:associate_user!)
        controller.associate_user
      end
    end
  end

  describe '#set_current_order' do
    let(:incomplete_order) { create(:order, user: user) }
    before { controller.stub(try_spree_current_user: user) }

    context 'when current order not equal to users incomplete orders' do
      before { controller.stub(current_order: order, last_incomplete_order: incomplete_order, cookies: double(signed: { guest_token: 'guest_token' })) }

      it 'calls Spree::Order#merge! method' do
        expect(order).to receive(:merge!).with(incomplete_order, user)
        controller.set_current_order
      end
    end
  end

  describe '#current_currency' do
    it 'returns current currency' do
      Spree::Config[:currency] = 'USD'
      expect(controller.current_currency).to eq 'USD'
    end
  end

  describe '#ip_address' do
    it 'returns remote ip' do
      expect(controller.ip_address).to eq request.remote_ip
    end
  end
end
