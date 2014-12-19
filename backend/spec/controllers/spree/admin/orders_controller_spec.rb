require 'spec_helper'
require 'cancan'
require 'spree/testing_support/bar_ability'

# Ability to test access to specific model instances
class OrderSpecificAbility
  include CanCan::Ability

  def initialize(user)
    can [:admin, :manage], Spree::Order, number: 'R987654321'
  end
end

describe Spree::Admin::OrdersController, type: :controller do

  context "with authorization" do
    stub_authorization!

    before do
      request.env["HTTP_REFERER"] = "http://localhost:3000"

      # ensure no respond_overrides are in effect
      if Spree::BaseController.spree_responders[:OrdersController].present?
        Spree::BaseController.spree_responders[:OrdersController].clear
      end
    end

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
      allow(Spree::Order).to receive_message_chain(:friendly, :find).and_return(order)
    end

    context "#approve" do
      it "approves an order" do
        expect(order).to receive(:approved_by).with(controller.try_spree_current_user)
        spree_put :approve, id: order.number
        expect(flash[:success]).to eq Spree.t(:order_approved)
      end
    end

    context "#cancel" do
      it "cancels an order" do
        expect(order).to receive(:canceled_by).with(controller.try_spree_current_user)
        spree_put :cancel, id: order.number
        expect(flash[:success]).to eq Spree.t(:order_canceled)
      end
    end

    context "#resume" do
      it "resumes an order" do
        expect(order).to receive(:resume!)
        spree_put :resume, id: order.number
        expect(flash[:success]).to eq Spree.t(:order_resumed)
      end
    end

    context "pagination" do
      it "can page through the orders" do
        spree_get :index, page: 2, per_page: 10
        expect(assigns[:orders].offset_value).to eq(10)
        expect(assigns[:orders].limit_value).to eq(10)
      end
    end

    # Test for #3346
    context "#new" do
      it "a new order has the current user assigned as a creator" do
        spree_get :new
        expect(assigns[:order].created_by).to eq(controller.try_spree_current_user)
      end
    end

    # Regression test for #3684
    context "#edit" do
      it "does not refresh rates if the order is completed" do
        allow(order).to receive_messages completed?: true
        expect(order).not_to receive :refresh_shipment_rates
        spree_get :edit, id: order.number
      end

      it "does refresh the rates if the order is incomplete" do
        allow(order).to receive_messages completed?: false
        expect(order).to receive :refresh_shipment_rates
        spree_get :edit, id: order.number
      end
    end

    # Test for #3919
    context "search" do
      let(:user) { create(:user) }

      before do
        allow(controller).to receive_messages spree_current_user: user
        user.spree_roles << Spree::Role.find_or_create_by(name: 'admin')

        create(:completed_order_with_totals)
        expect(Spree::Order.count).to eq 1
      end

      it "does not display duplicated results" do
        spree_get :index, q: {
          line_items_variant_id_in: Spree::Order.first.variants.map(&:id)
        }
        expect(assigns[:orders].map { |o| o.number }.count).to eq 1
      end
    end

    context "#open_adjustments" do
      let(:closed) { double('closed_adjustments') }

      before do
        allow(adjustments).to receive(:where).and_return(closed)
        allow(closed).to receive(:update_all)
      end

      it "changes all the closed adjustments to open" do
        expect(adjustments).to receive(:where).with(state: 'closed')
          .and_return(closed)
        expect(closed).to receive(:update_all).with(state: 'open')
        spree_post :open_adjustments, id: order.number
      end

      it "sets the flash success message" do
        spree_post :open_adjustments, id: order.number
        expect(flash[:success]).to eql('All adjustments successfully opened!')
      end

      it "redirects back" do
        spree_post :open_adjustments, id: order.number
        expect(response).to redirect_to(:back)
      end
    end

    context "#close_adjustments" do
      let(:open) { double('open_adjustments') }

      before do
        allow(adjustments).to receive(:where).and_return(open)
        allow(open).to receive(:update_all)
      end

      it "changes all the open adjustments to closed" do
        expect(adjustments).to receive(:where).with(state: 'open')
          .and_return(open)
        expect(open).to receive(:update_all).with(state: 'closed')
        spree_post :close_adjustments, id: order.number
      end

      it "sets the flash success message" do
        spree_post :close_adjustments, id: order.number
        expect(flash[:success]).to eql('All adjustments successfully closed!')
      end

      it "redirects back" do
        spree_post :close_adjustments, id: order.number
        expect(response).to redirect_to(:back)
      end
    end
  end

  context '#authorize_admin' do
    let(:user) { create(:user) }
    let(:order) { create(:completed_order_with_totals, number: 'R987654321') }

    before do
      allow(Spree::Order).to receive_messages find: order
      allow(controller).to receive_messages spree_current_user: user
    end

    it 'should grant access to users with an admin role' do
      user.spree_roles << Spree::Role.find_or_create_by(name: 'admin')
      spree_post :index
      expect(response).to render_template :index
    end

    it 'should grant access to users with an bar role' do
      user.spree_roles << Spree::Role.find_or_create_by(name: 'bar')
      Spree::Ability.register_ability(BarAbility)
      spree_post :index
      expect(response).to render_template :index
      Spree::Ability.remove_ability(BarAbility)
    end

    it 'should deny access to users with an bar role' do
      allow(order).to receive(:update_attributes).and_return true
      allow(order).to receive(:user).and_return Spree.user_class.new
      allow(order).to receive(:token).and_return nil
      user.spree_roles.clear
      user.spree_roles << Spree::Role.find_or_create_by(name: 'bar')
      Spree::Ability.register_ability(BarAbility)
      spree_put :update, id: order.number
      expect(response).to redirect_to('/unauthorized')
      Spree::Ability.remove_ability(BarAbility)
    end

    it 'should deny access to users without an admin role' do
      allow(user).to receive_messages has_spree_role?: false
      spree_post :index
      expect(response).to redirect_to('/unauthorized')
    end

    it 'should restrict returned order(s) on index when using OrderSpecificAbility' do
      number = order.number

      3.times { create(:completed_order_with_totals) }
      expect(Spree::Order.complete.count).to eq 4
      Spree::Ability.register_ability(OrderSpecificAbility)

      allow(user).to receive_messages has_spree_role?: false
      spree_get :index
      expect(response).to render_template :index
      expect(assigns['orders'].size).to eq 1
      expect(assigns['orders'].first.number).to eq number
      expect(Spree::Order.accessible_by(Spree::Ability.new(user), :index).pluck(:number)).to eq  [number]
    end
  end

  context "order number not given" do
    stub_authorization!

    it "raise active record not found" do
      expect {
        spree_get :edit, id: nil
      }.to raise_error ActiveRecord::RecordNotFound
    end
  end
end
