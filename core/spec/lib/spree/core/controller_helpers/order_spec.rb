require 'spec_helper'

class FakesController < ApplicationController
  include Spree::Core::ControllerHelpers::Store
  include Spree::Core::ControllerHelpers::Order
  include Spree::Core::ControllerHelpers::Currency
  include Spree::Core::ControllerHelpers::Locale
end

class ActionDispatch::Cookies::SignedKeyRotatingCookieJar
  def fetch_set_cookies
    @parent_jar.fetch_set_cookies
  end
end

class ActionDispatch::Cookies::CookieJar
  def fetch_set_cookies
    @set_cookies
  end
end

describe Spree::Core::ControllerHelpers::Order, type: :controller do
  controller(FakesController) {}

  let(:user) { create(:user) }
  let(:order) { create(:order, user: user, store: store) }
  let!(:store) { @default_store }

  describe '#simple_current_order' do
    before { allow(controller).to receive_messages(try_spree_current_user: user) }

    it 'returns an empty order' do
      expect(controller.simple_current_order.item_count).to eq 0
    end
    it 'returns Spree::Order instance' do
      allow(controller).to receive_messages(cookies: double(signed: { token: order.token }))
      expect(controller.simple_current_order).to eq order
    end
  end

  describe '#current_order' do
    before do
      allow(controller).to receive_messages(current_store: store)
      allow(controller).to receive_messages(try_spree_current_user: user)
    end

    context 'create_order_if_necessary option is false' do
      let!(:order) { create :order, user: user, store: store }

      it 'returns current order' do
        expect(controller.current_order).to eq order
      end
    end

    context 'create_order_if_necessary option is true' do
      it 'creates new order' do
        expect do
          controller.current_order(create_order_if_necessary: true)
        end.to change(Spree::Order, :count).to(1)
      end
    end

    describe 'creating a token cookie' do
      let!(:store) { create(:store, default: true, name: 'Test Cookie Store') }

      let(:token_cookie) { request.cookie_jar.signed[:token] }
      let(:token_cookie_domain) { request.cookie_jar.signed.fetch_set_cookies.dig('token', :domain) }

      context 'for a cart with token' do
        before do
          allow(controller).to receive(:current_order_params).and_return(
            token: 'token-123',
            currency: 'USD',
            user_id: user.id
          )
        end

        it 'creates a new token cookie' do
          controller.current_order

          expect(token_cookie).to be_present
          expect(token_cookie_domain).to eq(store.url)
        end

        context 'on a custom domain' do
          let!(:custom_domain) { create(:custom_domain, store: store, url: 'test-cookie-store.com') }

          it 'creates a new token cookie on a custom domain' do
            controller.current_order

            expect(token_cookie).to be_present
            expect(token_cookie_domain).to eq('test-cookie-store.com')
          end
        end
      end

      context 'for a cart without token' do
        before do
          allow(controller).to receive(:current_order_params).and_return(
            token: nil,
            currency: 'USD',
            user_id: user.id
          )
        end

        it 'does nothing' do
          controller.current_order
          expect(token_cookie).to be_nil
        end
      end

      context 'with a checkout token' do
        before do
          allow(controller).to receive(:params).and_return(token: 'token-123')
        end

        it 'creates a new token cookie' do
          controller.current_order

          expect(token_cookie).to be_present
          expect(token_cookie_domain).to eq(store.url)
        end

        context 'on a custom domain' do
          let!(:custom_domain) { create(:custom_domain, store: store, url: 'test-cookie-store.com') }

          it 'creates a new token cookie on a custom domain' do
            controller.current_order

            expect(token_cookie).to be_present
            expect(token_cookie_domain).to eq('test-cookie-store.com')
          end
        end
      end

      context 'for a checkout without token' do
        before do
          allow(controller).to receive(:params).and_return(token: nil)
        end

        it 'does nothing' do
          controller.current_order
          expect(token_cookie).to be_nil
        end
      end
    end
  end

  describe '#associate_user' do
    before do
      allow(controller).to receive_messages(current_order: order, try_spree_current_user: user)
    end

    context "user is blank" do
      let(:order) { create(:order, user: nil, store: store) }

      it 'calls Spree::Order#associate_user! method' do
        expect_any_instance_of(Spree::Order).to receive(:associate_user!)
        controller.associate_user
      end
    end

    context "user isn't blank" do
      let(:order) { create(:order, user: user, store: store) }

      it 'does not calls Spree::Order#associate_user! method' do
        expect_any_instance_of(Spree::Order).not_to receive(:associate_user!)
        controller.associate_user
      end
    end
  end

  describe '#set_current_order' do
    before { allow(controller).to receive_messages(try_spree_current_user: user) }

    context 'user has some incomplete orders other than current one' do
      before do
        allow(controller).to receive_messages(current_order: order, last_incomplete_order: incomplete_order, cookies: double(signed: { token: 'token' }))
      end

      context 'within the same store' do
        let!(:incomplete_order) { create(:order, user: user, store: order.store) }

        it 'calls Spree::Order#merge!' do
          expect(order).to receive(:merge!).with(incomplete_order, user)
          controller.set_current_order
        end
      end

      context 'within different store' do
        let!(:incomplete_order) { create(:order, user: user, store: create(:store)) }

        it 'does not call Spree::Order#merge!' do
          expect(order).not_to receive(:merge!)
          controller.set_current_order
        end
      end
    end

    context 'user has no incomplete orders other than current one' do
      it 'does not call Spree::Order#merge!' do
        expect(order).not_to receive(:merge!)
        controller.set_current_order
      end
    end
  end

  describe '#current_currency' do
    it 'returns current currency' do
      expect(controller.current_currency).to eq 'USD'
    end
  end

  describe '#ip_address' do
    it 'returns remote ip' do
      expect(controller.ip_address).to eq request.remote_ip
    end
  end

  describe '#create_token_cookie' do
    it 'creates a new token cookie' do
      controller.send(:create_token_cookie, 'token-123')
      expect(request.cookie_jar.signed[:token]).to eq 'token-123'
    end
  end
end
