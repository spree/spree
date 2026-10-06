require 'spec_helper'

module Spree
  module PromotionHandler
    describe Cart, type: :model do
      subject { Cart.new(order, line_item) }

      let(:line_item) { create(:line_item) }
      let(:order) { line_item.order }

      let(:promotion) { create(:promotion, name: 'At line items', store: order.store, kind: :automatic) }
      let(:calculator) { Calculator::FlatPercentItemTotal.new(preferred_flat_percent: 10) }

      context 'activates in LineItem level' do
        let!(:action) { Promotion::Actions::CreateItemAdjustments.create(promotion: promotion, calculator: calculator) }
        let(:adjustable) { line_item }

        shared_context 'creates the adjustment' do
          it 'creates the adjustment' do
            expect do
              subject.activate
            end.to change { adjustable.discounts.count }.by(1)
          end
        end

        context 'promotion with no rules' do
          include_context 'creates the adjustment'
        end

        context 'promotion includes item involved' do
          let!(:rule) { Promotion::Rules::Product.create(products: [line_item.product], promotion: promotion) }

          include_context 'creates the adjustment'
        end

        context 'promotion has item total rule' do
          let(:shirt) { create(:product, store: order.store) }
          let!(:rule) { Promotion::Rules::ItemTotal.create(preferred_operator_min: 'gt', preferred_amount_min: 50, preferred_operator_max: 'lt', preferred_amount_max: 150, promotion: promotion) }

          before do
            # Makes the order eligible for this promotion
            order.item_total = 100
            order.save
          end

          include_context 'creates the adjustment'
        end
      end

      context 'activates in Order level' do
        let!(:action) { Promotion::Actions::CreateAdjustment.create(promotion: promotion, calculator: calculator) }
        let(:adjustable) { order }

        shared_context 'creates the adjustment' do
          it 'creates the adjustment' do
            expect do
              subject.activate
            end.to change { adjustable.discounts.count }.by(1)
          end
        end

        context 'promotion with no rules' do
          before do
            # Gives the calculator something to discount
            order.item_total = 10
            order.save
          end

          include_context 'creates the adjustment'
        end

        context 'promotion has item total rule' do
          let(:shirt) { create(:product, store: order.store) }
          let!(:rule) { Promotion::Rules::ItemTotal.create(preferred_operator_min: 'gt', preferred_amount_min: 50, preferred_operator_max: 'lt', preferred_amount_max: 150, promotion: promotion) }

          before do
            # Makes the order eligible for this promotion
            order.item_total = 100
            order.save
          end

          include_context 'creates the adjustment'
        end
      end

      context 'activates promotions associated with the order' do
        let(:promo) { create :promotion_with_item_adjustment, adjustment_rate: 5, code: 'promo' }
        let(:adjustable) { line_item }

        before do
          order.promotions << promo
        end

        it 'creates the adjustment' do
          expect do
            subject.activate
          end.to change { adjustable.discounts.count }.by(1)
        end
      end

      context 'with a gift code saved before the cart qualifies' do
        let(:cart) { create(:cart) }
        let(:tote) { create(:variant) }
        let(:mug) { create(:variant) }
        let!(:gift_promotion) do
          create(:promotion, kind: :coupon_code, code: 'totegift', store: cart.store).tap do |promotion|
            create(:promotion_rule_product, promotion: promotion).products << tote.product
            create(:promotion_action_create_line_items, promotion: promotion).
              promotion_action_line_items.create!(variant: mug, quantity: 2)
          end
        end

        before { cart.update_column(:coupon_code, 'totegift') }

        it 'adds the gift once the cart qualifies' do
          Spree.cart_add_item_workflow.call(cart: cart, variant: tote, quantity: 1)

          expect(cart.line_items.reload.find_by(variant_id: mug.id).gifted_quantity).to eq(2)
          expect(cart.promotions).to include(gift_promotion)
        end

        it 'adds nothing while the cart does not qualify' do
          Spree.cart_add_item_workflow.call(cart: cart, variant: create(:variant), quantity: 1)

          expect(cart.line_items.reload.map(&:variant_id)).not_to include(mug.id)
          expect(cart.promotions).to be_empty
        end
      end
    end
  end
end
