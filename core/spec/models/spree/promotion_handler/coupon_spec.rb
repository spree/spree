require 'spec_helper'

module Spree
  module PromotionHandler
    describe Coupon, type: :model do
      subject { Coupon.new(order) }

      let(:order) { double('Order', coupon_code: '10off').as_null_object }

      it 'returns self in apply' do
        expect(subject.apply).to be_a Coupon
      end

      context 'status messages' do
        let(:coupon) { Coupon.new(order) }

        describe '#set_success_code' do
          subject { coupon.set_success_code status }

          let(:status) { :coupon_code_applied }

          it 'has status_code' do
            subject
            expect(coupon.status_code).to eq(status)
          end

          it 'has success message' do
            subject
            expect(coupon.success).to eq(Spree.t(status))
          end
        end

        describe '#set_error_code' do
          subject { coupon.set_error_code status }

          let(:status) { :coupon_code_not_found }

          it 'has status_code' do
            subject
            expect(coupon.status_code).to eq(status)
          end

          it 'has error message' do
            subject
            expect(coupon.error).to eq(Spree.t(status))
          end
        end
      end

      context 'coupon code promotion doesnt exist' do
        before { create(:promotion, name: 'promo', code: nil) }

        it 'doesnt fetch any promotion' do
          expect(subject.promotion).to be_blank
        end

        context 'with no actions defined' do
          before { create(:promotion, name: 'promo', code:'10off') }

          it 'populates error message' do
            subject.apply
            expect(subject.error).to eq Spree.t(:coupon_code_not_found)
          end
        end
      end

      context 'existing coupon code promotion' do
        let!(:promotion) { create(:promotion, :with_line_item_adjustment, adjustment_rate: 10, code: '10off') }

        it 'fetches with given code' do
          expect(subject.promotion).to eq promotion
        end

        context 'with a per-item adjustment action' do
          let(:order) { create(:order_with_line_items, line_items_count: 3) }

          context 'right coupon given' do
            context 'with correct coupon code casing' do
              before { allow(order).to receive_messages coupon_code: '10off' }

              it 'successfully activates promo' do
                expect(order.total).to eq(130)
                subject.apply
                expect(subject.success).to be_present
                order.line_items.each do |line_item|
                  expect(line_item.adjustments.count).to eq(1)
                end
                # Ensure that applying the adjustment actually affects the order's total!
                expect(order.reload.total).to eq(100)
              end

              it 'coupon already applied to the order' do
                subject.apply
                expect(subject.success).to be_present
                subject.apply
                expect(subject.error).to eq Spree.t(:coupon_code_already_applied)
              end
            end

            # Regression test for #4211
            context 'with incorrect coupon code casing' do
              before { allow(order).to receive_messages coupon_code: '10OFF' }

              it 'successfully activates promo' do
                expect(order.total).to eq(130)
                subject.apply
                expect(subject.success).to be_present
                order.line_items.each do |line_item|
                  expect(line_item.adjustments.count).to eq(1)
                end
                # Ensure that applying the adjustment actually affects the order's total!
                expect(order.reload.total).to eq(100)
              end
            end
          end

          context 'coexists with a non coupon code promo' do
            let!(:order) { create(:order) }

            before do
              allow(order).to receive_messages coupon_code: '10off'
              calculator = Calculator::FlatRate.new(preferred_amount: 10)
              general_promo = Promotion.create name: 'General Promo'
              Promotion::Actions::CreateItemAdjustments.create(promotion: general_promo, calculator: calculator) # general_action

              Spree::Cart::AddItem.call(order: order, variant: create(:variant))
            end

            # regression spec for #4515
            it 'successfully activates promo' do
              subject.apply
              expect(subject).to be_successful
            end
          end
        end

        context 'with a free-shipping adjustment action' do
          let!(:action) { Promotion::Actions::FreeShipping.create(promotion: promotion) }

          context 'right coupon code given' do
            let(:order) { create(:order_with_line_items, line_items_count: 3) }

            before { allow(order).to receive_messages coupon_code: '10off' }

            it 'successfully activates promo' do
              expect(order.total).to eq(130)
              subject.apply
              expect(subject.success).to be_present

              expect(order.shipment_adjustments.count).to eq(1)
            end

            it 'coupon already applied to the order' do
              subject.apply
              expect(subject.success).to be_present
              subject.apply
              expect(subject.error).to eq Spree.t(:coupon_code_already_applied)
            end
          end
        end

        context 'with a whole-order adjustment action' do
          let!(:action) { Promotion::Actions::CreateAdjustment.create(promotion: promotion, calculator: calculator) }

          context 'right coupon given' do
            let(:order) { create(:order) }
            let(:calculator) { Calculator::FlatRate.new(preferred_amount: 10) }

            before do
              allow(order).to receive_messages(coupon_code: '10off',
                                               # These need to be here so that promotion adjustment "wins"
                                               item_total: 50,
                                               ship_total: 10)
            end

            it 'successfully activates promo' do
              subject.apply
              expect(subject.success).to be_present
              expect(order.adjustments.count).to eq(1)
            end

            it 'coupon already applied to the order' do
              subject.apply
              expect(subject.success).to be_present
              subject.apply
              expect(subject.error).to eq Spree.t(:coupon_code_already_applied)
            end

            it 'coupon fails to activate' do
              allow_any_instance_of(Spree::Promotion).to receive(:activate).and_return false
              subject.apply
              expect(subject.error).to eq Spree.t(:coupon_code_unknown_error)
            end

            it 'coupon code hit max usage' do
              promotion.update_column(:usage_limit, 1)
              subject.apply
              expect(subject.successful?).to be true

              order_2 = create(:order)
              allow(order_2).to receive_messages coupon_code: '10off'
              coupon = Coupon.new(order_2)
              coupon.apply
              expect(coupon.successful?).to be false
              expect(coupon.error).to eq Spree.t(:coupon_code_max_usage)
            end

            context 'when the a new coupon is less good' do
              let!(:promotion_5) { create(:promotion, :with_order_adjustment, weighted_order_adjustment_amount: 5, name: 'promo', code: '5off') }

              it 'notifies of better deal' do
                subject.apply
                allow(order).to receive_messages(coupon_code: '5off')
                coupon = Coupon.new(order).apply
                expect(coupon.error).to eq Spree.t(:coupon_code_better_exists)
              end
            end
          end
        end

        context 'for an order with taxable line items' do
          let!(:order)         { create(:order, line_items_price: 0.0) }
          let!(:zone)          { create(:zone_with_country, default_tax: true) }
          let!(:tax_category)  { create(:tax_category, name: 'Taxable Foo') }
          let!(:rate)          { create(:tax_rate, amount: 0.10, tax_category: tax_category, zone: zone) }

          before { allow(order).to receive(:coupon_code).and_return '10off' }

          context 'and the product price is less than promo discount' do
            let(:product_list) { create_list(:product, 3, tax_category: tax_category, price: 9.0) }

            before { product_list.each { |item| Spree::Cart::AddItem.call(order: order, variant: item.master) } }

            it 'successfully applies the promo' do
              # 3 * (9 + 0.9)
              expect(order.total).to eq(29.7)
              subject.apply
              expect(subject.success).to be_present
              # 3 * ((9 - [9,10].min) + 0)
              expect(order.reload.total).to eq(0)
              expect(order.additional_tax_total).to eq(0)
            end
          end

          context 'and the product price is greater than promo discount' do
            let(:product_list) { create_list(:product, 3, tax_category: tax_category, price: 11.0) }

            before { product_list.each { |item| Spree::Cart::AddItem.call(order: order, variant: item.master, quantity: 2) } }

            it 'successfully applies the promo' do
              # 3 * (22 + 2.2)
              expect(order.total.to_f).to eq(72.6)
              subject.apply
              expect(subject.success).to be_present
              # 3 * ( (22 - 10) + 1.2)
              expect(order.reload.total).to eq(39.6)
              expect(order.additional_tax_total).to eq(3.6)
            end
          end

          context 'and multiple quantity per line item' do
            let(:promotion)    { create(:promotion, :with_line_item_adjustment, adjustment_rate: 20, code: '20off') }
            let(:product_list) { create_list(:product, 3, tax_category: tax_category, price: 10.0) }

            before do
              allow(order).to receive(:coupon_code).and_return '20off'
              product_list.each { |item| Spree::Cart::AddItem.call(order: order, variant: item.master, quantity: 2) }
            end

            it 'successfully applies the promo' do
              # 3 * ((2 * 10) + 2.0)
              expect(order.total.to_f).to eq(66)
              subject.apply
              expect(subject.success).to be_present
              # 0
              expect(order.reload.total).to eq(0)
              expect(order.additional_tax_total).to eq(0)
            end
          end
        end

        context 'with a CreateLineItems action' do
          let!(:variant) { create(:variant) }
          let!(:action) { Promotion::Actions::CreateLineItems.create(promotion: promotion) }
          let(:order) { create(:order) }

          before do
            action.promotion_action_line_items.create(
              variant: variant,
              quantity: 1
            )
            allow(order).to receive_messages(coupon_code: '10off')
          end

          it 'successfully activates promo' do
            subject.apply
            expect(subject.success).to be_present
            expect(order.line_items.pluck(:variant_id)).to include(variant.id)
          end
        end
      end
    end
  end
end
