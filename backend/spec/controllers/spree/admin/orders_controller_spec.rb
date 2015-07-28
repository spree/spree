require 'spec_helper'
require 'cancan'
require 'spree/testing_support/bar_ability'

# Ability to test access to specific model instances
class OrderSpecificAbility
  include CanCan::Ability

  def initialize(user)
    can %i[admin manage], Spree::Order, number: 'R987654321'
  end
end

describe Spree::Admin::OrdersController, type: :controller do
  shared_context 'setup order' do
    let(:order) do
      mock_model(
        Spree::Order,
        completed?:      true,
        total:           100,
        number:          'R123456789',
        all_adjustments: adjustments,
        billing_address: mock_model(Spree::Address)
      )
    end

    let(:adjustments) { double('adjustments') }

    before do
      allow(Spree::Order).to receive_messages(find_by_number!: order)
    end
  end

  before do
    request.env['HTTP_REFERER'] = 'http://localhost:3000'

    # ensure no respond_overrides are in effect
    if Spree::BaseController.spree_responders[:OrdersController].present?
      Spree::BaseController.spree_responders[:OrdersController].clear
    end
  end

  context '#approve' do
    stub_authorization!
    include_context 'setup order'

    it 'approves an order' do
      expect(order).to receive(:approved_by).with(controller.try_spree_current_user)
      spree_put(:approve, id: order.number)
      expect(flash[:success]).to eql(Spree.t(:order_approved))
    end
  end

  context '#cancel' do
    stub_authorization!
    include_context 'setup order'

    it 'cancels an order' do
      expect(order).to receive(:canceled_by).with(controller.try_spree_current_user)
      spree_put(:cancel, id: order.number)
      expect(flash[:success]).to eql(Spree.t(:order_canceled))
    end
  end

  describe '#resume' do
    stub_authorization!
    include_context 'setup order'

    it 'resumes an order' do
      expect(order).to receive(:resume!)
      spree_put(:resume, id: order.number)
      expect(flash[:success]).to eql(Spree.t(:order_resumed))
    end
  end

  describe '#index' do
    stub_authorization!

    it 'can page through the orders' do
      spree_get(:index, page: 2, per_page: 10)
      expect(assigns[:orders].offset_value).to be(10)
      expect(assigns[:orders].limit_value).to be(10)
    end
  end

  describe '#new' do
    stub_authorization!

    def do_request
      spree_get :new, user_id: user_id
    end

    shared_examples_for '#new' do
      it 'does not use the other incomplete order' do
        expect(assigns[:order]).to_not eql(other_incomplete_order)
      end

      it 'does not use the incomplete order for other user' do
        expect(assigns[:order]).to_not eql(incomplete_order_other_user)
      end

      # Test for #3346
      it 'a new order has the current user assigned as a creator' do
        expect(assigns[:order].created_by).to eql(controller.try_spree_current_user)
      end

      it 'sets the expected user' do
        expect(assigns[:order].user).to eql(user)
      end

      it 'redirects to the order edit url' do
        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(
          "http://test.host/admin/orders/#{assigns[:order].number}/cart"
        )
      end
    end

    let(:user)    { nil }
    let(:user_id) { nil }

    # Create incomplete order with a nil user to ensure the
    # order scope filters out orders with a nil user_id
    let!(:other_incomplete_order) do
      create(
        :order_with_line_items,
        user:  nil,
        email: 'test@example.com'
      )
    end

    # Create incomplete order with another user to ensure the
    # order scope searches for a nil user id
    let!(:incomplete_order_other_user) do
      create(:order_with_line_items)
    end

    context 'when the user_id is not provided' do
      include_examples '#new'

      def do_request
        spree_get(:new)
      end

      before { do_request }
    end

    context 'when the user_id is provided' do
      let(:user)    { create(:user) }
      let(:user_id) { user.id       }

      context 'the user has no incomplete orders' do
        include_examples '#new'

        let!(:complete_order) do
          create(:completed_order_with_totals, user: user)
        end

        before { do_request }

        it 'creates an order' do
          expect(assigns[:order]).to_not be_a_new(Spree::Order)
        end

        it 'does not use the complete order' do
          expect(assigns[:order]).to_not eql(complete_order)
        end
      end

      context 'the user has incomplete orders' do
        include_examples '#new'

        let(:user) { create(:user_with_addreses) }

        let!(:incomplete_order) do
          create(:order_with_line_items, user: user, created_by: user)
        end

        before { do_request }

        it 'uses the incomplete order' do
          expect(assigns[:order]).to eql(incomplete_order)
        end

        it 'advances the order to the latest possible state' do
          expect(assigns[:order].state).to eql('payment')
        end
      end
    end
  end

  describe '#edit' do
    stub_authorization!
    include_context 'setup order'

    let(:order) { create(:order) }

    it 'advances the order' do
      expect(order).to receive(:advance).and_call_original
      spree_get(:edit, id: order.number)
    end

    it 'silences errors' do
      spree_get(:edit, id: order.number)
      expect(order.errors).to be_empty
    end
  end

  # Test for #3919
  describe '#search' do
    stub_authorization!

    let(:user) { create(:user) }

    before do
      allow(controller).to receive_messages(spree_current_user: user)
      user.spree_roles << Spree::Role.find_or_create_by(name: 'admin')

      create(:completed_order_with_totals)
      expect(Spree::Order.count).to be(1)
    end

    it 'does not display duplicated results' do
      spree_get :index, q: {
        line_items_variant_id_in: Spree::Order.first!.variants.map(&:id)
      }
      expect(assigns[:orders].map(&:number).count).to be(1)
    end
  end

  context '#open_adjustments' do
    stub_authorization!
    include_context 'setup order'

    let(:closed) { double('closed_adjustments') }

    before do
      allow(adjustments).to receive(:where)
        .and_return(closed)

      allow(closed).to receive(:update_all)
    end

    def do_request
      spree_post(:open_adjustments, id: order.number)
    end

    it 'changes all the closed adjustments to open' do
      expect(adjustments).to receive(:where)
        .with(state: 'closed')
        .and_return(closed)

      expect(closed).to receive(:update_all)
        .with(state: 'open')

      do_request
    end

    it 'sets the flash success message' do
      do_request

      expect(flash[:success]).to eql('All adjustments successfully opened!')
    end

    it 'redirects back' do
      do_request

      expect(response).to redirect_to(:back)
    end
  end

  context '#close_adjustments' do
    stub_authorization!
    include_context 'setup order'

    let(:open) { double('open_adjustments') }

    before do
      allow(adjustments).to receive(:where).and_return(open)
      allow(open).to receive(:update_all)
    end

    def do_request
      spree_post(:close_adjustments, id: order.number)
    end

    it 'changes all the open adjustments to closed' do
      expect(adjustments).to receive(:where).with(state: 'open')
        .and_return(open)

      expect(open).to receive(:update_all).with(state: 'closed')

      do_request
    end

    it 'sets the flash success message' do
      do_request

      expect(flash[:success]).to eql('All adjustments successfully closed!')
    end

    it 'redirects back' do
      do_request

      expect(response).to redirect_to(:back)
    end
  end

  describe '#authorize_admin' do
    let(:user)  { create(:user)                                              }
    let(:order) { create(:completed_order_with_totals, number: 'R987654321') }

    def with_ability(ability)
      Spree::Ability.register_ability(ability)
      yield
    ensure
      Spree::Ability.remove_ability(ability)
    end

    before do
      allow(Spree::Order).to receive_messages(find_by_number!: order)
      allow(controller).to receive_messages(spree_current_user: user)
    end

    it 'should grant access to users with an admin role' do
      user.spree_roles << Spree::Role.find_or_create_by(name: 'admin')
      spree_post(:index)
      expect(response).to render_template(:index)
    end

    it 'should grant access to users with an bar role' do
      with_ability(BarAbility) do
        user.spree_roles << Spree::Role.find_or_create_by(name: 'bar')
        spree_post(:index)
        expect(response).to render_template(:index)
      end
    end

    it 'should deny access to users with an bar role' do
      with_ability(BarAbility) do
        allow(order).to receive_messages(
          update_attributes: true,
          user:              Spree.user_class.new,
          token:             nil
        )
        user.spree_roles = [Spree::Role.find_or_create_by(name: 'bar')]
        spree_put(:update, id: 'R123')
        expect(response).to redirect_to('/unauthorized')
      end
    end

    it 'should deny access to users without an admin role' do
      allow(user).to receive_messages(has_spree_role?: false)
      spree_post(:index)
      expect(response).to redirect_to('/unauthorized')
    end

    it 'should restrict returned order(s) on index when using OrderSpecificAbility' do
      number = order.number

      3.times { create(:completed_order_with_totals) }
      expect(Spree::Order.complete.count).to be(4)

      with_ability(OrderSpecificAbility) do
        allow(user).to receive_messages(has_spree_role?: false)
        spree_get(:index)
        expect(response).to render_template(:index)
        expect(assigns['orders'].size).to be(1)
        expect(assigns['orders'].first.number).to eql(number)
        expect(Spree::Order.accessible_by(Spree::Ability.new(user), :index).pluck(:number))
          .to eql([number])
      end
    end
  end

  context 'order number not given' do
    stub_authorization!

    it 'raise active record not found' do
      expect {
        spree_get(:edit, id: nil)
      }.to raise_error ActiveRecord::RecordNotFound
    end
  end
end
