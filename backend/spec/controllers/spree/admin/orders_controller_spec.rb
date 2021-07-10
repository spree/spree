require 'spec_helper'
require 'cancan'
require 'spree/testing_support/bar_ability'

# Ability to test access to specific model instances
class OrderSpecificAbility
  include CanCan::Ability

  def initialize(_user)
    can [:admin, :manage], Spree::Order, number: 'R987654321'
  end
end

describe Spree::Admin::OrdersController, type: :controller do
  let(:store) { Spree::Store.default }

  shared_examples 'refreshes shipping rates conditionally' do |action_name|
    let(:shipments) { order.reload.shipments }

    before do
      order.shipments.each { |s| s.shipping_rates.destroy_all }
      get action_name, params: { id: order.number }
    end

    context 'when order is not completed' do
      it { expect(shipments.map(&:shipping_rates).flatten).not_to be_empty }
      it { expect(shipments.first.selected_shipping_rate.shipping_method.available_to_display?(display_value)).to be_truthy }
    end

    context 'when order is complete' do
      let(:order) { create(:order_ready_to_ship, store: store) }

      it { expect(shipments.map(&:shipping_rates).flatten).to be_empty }
    end
  end

  context 'with authorization' do
    stub_authorization!

    let(:order) { create(:order_with_line_items, number: 'R123456789', store: store) }
    let(:adjustments) { order.all_adjustments.reload }
    let(:admin_user) { create(:admin_user) }
    let(:display_value) { Spree::ShippingMethod::DISPLAY_ON_BACK_END }

    before do
      allow(controller).to receive(:try_spree_current_user).and_return(admin_user)
    end

    describe '#approve' do
      it 'approves an order' do
        put :approve, params: { id: order.number }
        expect(flash[:success]).to eq Spree.t(:order_approved)
        order.reload
        expect(order.approved?).to eq true
        expect(order.approver).to eq admin_user
      end
    end

    describe '#cancel' do
      let(:order) { create(:order_ready_to_ship, store: store) }

      it 'cancels an order' do
        put :cancel, params: { id: order.number }
        expect(flash[:success]).to eq Spree.t(:order_canceled)
        order.reload
        expect(order.canceled?).to eq true
        expect(order.canceler).to eq admin_user
      end
    end

    describe '#channel' do
      subject do
        get :channel, params: { id: order.number }
      end

      it 'displays a page with channel input' do
        expect(subject).to render_template :channel
      end
    end

    context '#set_channel' do
      it 'sets channel on an order' do
        put :set_channel, params: { id: order.number, channel: 'POS' }
        expect(order.reload.channel).to eq 'POS'

        expect(flash[:success]).to eq Spree.t(:successfully_updated, resource: 'Order')
      end
    end

    describe '#resume' do
      let(:order) { create(:order, state: 'canceled', store: store) }

      it 'resumes an order' do
        put :resume, params: { id: order.number }
        order.reload
        expect(order.resumed?).to eq(true)
        expect(flash[:success]).to eq Spree.t(:order_resumed)
      end
    end

    context 'pagination' do
      it 'can page through the orders' do
        get :index, params: { page: 2, per_page: 10 }
        expect(assigns[:orders].offset_value).to eq(10)
        expect(assigns[:orders].limit_value).to eq(10)
      end
    end

    # Test for #3346
    describe '#new' do
      it 'a new order has the current user assigned as a creator and proper store' do
        get :new
        expect(assigns[:order].created_by).to eq(admin_user)
        expect(assigns[:order].store).to eq(store)
      end
    end

    # Regression test for #3684
    describe '#edit' do
      it_behaves_like 'refreshes shipping rates conditionally', :edit
    end

    describe '#cart' do
      it_behaves_like 'refreshes shipping rates conditionally', :cart
    end

    # Test for #3919
    context 'search' do
      before do
        create(:completed_order_with_totals)
        expect(Spree::Order.count).to eq 1
      end

      def send_request
        get :index, params: {
          q: {
            line_items_variant_id_in: Spree::Order.first.variant_ids
          }
        }
      end

      it 'does not display duplicate results' do
        send_request
        expect(assigns[:orders].map(&:number).count).to eq 1
      end

      it 'preloads users' do
        allow(Spree::Order).to receive(:preload).with(:user).and_return(Spree::Order.all)
        send_request
      end
    end

    describe '#open_adjustments' do
      let(:order) { create(:order_ready_to_ship, store: store) }
      let(:shipment) { order.shipments.first }

      before do
        shipment.adjustments.create!(
          order: order,
          label: 'Additional',
          amount: 5,
          included: false,
          state: 'closed'
        )
        shipment.update_amounts
      end

      it 'changes all the closed adjustments to open' do
        post :open_adjustments, params: { id: order.number }
        expect(adjustments.map(&:state)).to eq(['open'])
      end

      it 'sets the flash success message' do
        post :open_adjustments, params: { id: order.number }
        expect(flash[:success]).to eql('All adjustments successfully opened!')
      end

      context 'when referer' do
        before do
          request.env['HTTP_REFERER'] = '/'
        end

        it 'redirects back' do
          post :open_adjustments, params: { id: order.number }
          expect(response).to redirect_to('/')
        end
      end

      context 'when no referer' do
        before do
          request.env['HTTP_REFERER'] = nil
        end

        it 'refirects to fallback location' do
          post :open_adjustments, params: { id: order.number }
          expect(response).to redirect_to(admin_order_adjustments_url(order))
        end
      end
    end

    describe '#close_adjustments' do
      let(:order) { create(:order_ready_to_ship, store: store) }
      let(:shipment) { order.shipments.first }

      before do
        shipment.adjustments.create!(
          order: order,
          label: 'Additional',
          amount: 5,
          included: false,
          state: 'open'
        )
        shipment.update_amounts
      end

      it 'changes all the open adjustments to closed' do
        post :close_adjustments, params: { id: order.number }
        expect(adjustments.map(&:state)).to eq(['closed'])
      end

      it 'sets the flash success message' do
        post :close_adjustments, params: { id: order.number }
        expect(flash[:success]).to eql('All adjustments successfully closed!')
      end

      context 'when referer' do
        before do
          request.env['HTTP_REFERER'] = '/'
        end

        it 'redirects back' do
          post :close_adjustments, params: { id: order.number }
          expect(response).to redirect_to('/')
        end
      end

      context 'when no referer' do
        before do
          request.env['HTTP_REFERER'] = nil
        end

        it 'refirects to fallback location' do
          post :close_adjustments, params: { id: order.number }
          expect(response).to redirect_to(admin_order_adjustments_url(order))
        end
      end
    end
  end

  describe '#authorize_admin' do
    let(:user) { create(:user) }
    let(:order) { create(:completed_order_with_totals, number: 'R987654321') }

    def with_ability(ability)
      Spree::Ability.register_ability(ability)
      yield
    ensure
      Spree::Ability.remove_ability(ability)
    end

    before do
      allow(Spree::Order).to receive_messages find: order
      allow(controller).to receive_messages spree_current_user: user
    end

    it 'grants access to users with an admin role' do
      user.spree_roles << Spree::Role.find_or_create_by(name: 'admin')
      post :index
      expect(response).to render_template :index
    end

    it 'grants access to users with an bar role' do
      with_ability(BarAbility) do
        user.spree_roles << Spree::Role.find_or_create_by(name: 'bar')
        post :index
        expect(response).to render_template :index
      end
    end

    it 'denies access to users with an bar role' do
      with_ability(BarAbility) do
        allow(order).to receive(:update).and_return true
        allow(order).to receive(:user).and_return Spree.user_class.new
        allow(order).to receive(:token).and_return nil
        user.spree_roles.clear
        user.spree_roles << Spree::Role.find_or_create_by(name: 'bar')
        put :update, params: { id: order.number }
        expect(response).to redirect_to(spree.forbidden_path)
      end
    end

    it 'denies access to users without an admin role' do
      allow(user).to receive_messages has_spree_role?: false
      post :index
      expect(response).to redirect_to(spree.forbidden_path)
    end

    it 'denies access to not signed in users' do
      allow(controller).to receive_messages spree_current_user: nil
      get :index
      expect(response).to redirect_to('/')
    end

    it 'restricts returned order(s) on index when using OrderSpecificAbility' do
      number = order.number

      create_list(:completed_order_with_totals, 3)
      expect(Spree::Order.complete.count).to eq 4

      with_ability(OrderSpecificAbility) do
        allow(user).to receive_messages has_spree_role?: false
        get :index
        expect(response).to render_template :index
        expect(assigns['orders'].distinct(false).size).to eq 1
        expect(assigns['orders'].first.number).to eq number
        expect(Spree::Order.accessible_by(Spree::Ability.new(user), :index).pluck(:number)).to eq [number]
      end
    end
  end

  context 'wrong order number' do
    stub_authorization!

    it 'redirects to orders list' do
      get :edit, params: { id: 99_999_999 }

      expect(response).to redirect_to(spree.admin_orders_path)
    end
  end

  context 'order from another store' do
    stub_authorization!

    let(:order) { create(:order_with_line_items, store: create(:store)) }

    it 'redirects to orders list' do
      get :edit, params: { id: order.number }

      expect(response).to redirect_to(spree.admin_orders_path)
    end
  end
end
