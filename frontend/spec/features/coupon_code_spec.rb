require 'spec_helper'

describe 'Coupon code promotions', type: :feature, js: true do
  include_context 'checkout setup'

  before { add_to_cart(mug) }
  
  context 'visitor makes checkout as guest without registration' do
    def create_basic_coupon_promotion(code)
      promotion = create(:promotion, name: code.titleize,
                                     code: code,
                                     starts_at: 1.day.ago,
                                     expires_at: 1.day.from_now)

      calculator = Spree::Calculator::FlatRate.new
      calculator.preferred_amount = 10

      action = Spree::Promotion::Actions::CreateAdjustment.new
      action.calculator = calculator
      action.promotion = promotion
      action.save

      promotion.reload # so that promotion.actions is available
    end

    let!(:promotion) { create_basic_coupon_promotion('onetwo') }

    shared_examples 'apply coupon code' do
      it 'informs about an invalid coupon code' do
        apply_coupon('coupon_codes_rule_man')
        expect(page).to have_content(Spree.t(:coupon_code_not_found))
      end

      it 'informs the user about a coupon code which has exceeded its usage' do
        promotion.update_column(:usage_limit, 5)
        allow_any_instance_of(promotion.class).to receive_messages(credits_count: 10)

        apply_coupon('onetwo')
        expect(page).to have_content(Spree.t(:coupon_code_max_usage))
      end

      it 'can enter an invalid coupon code, then a real one' do
        apply_coupon('coupon_codes_rule_man')
        expect(page).to have_content(Spree.t(:coupon_code_not_found))

        apply_coupon('onetwo')
        expect(page).to have_field('order_applied_coupon_code', with: 'Promotion (Onetwo)')
      end

      context 'with a promotion' do
        it 'applies a promotion to an order and later removes it' do
          apply_coupon('onetwo')
          expect(page).to have_field('order_applied_coupon_code', with: 'Promotion (Onetwo)')
          find('.shopping-cart-coupon-code button').click
          expect(page).not_to have_field('order_applied_coupon_code', with: 'Promotion (Onetwo)')
        end
      end
    end

    context 'cart' do
      it_behaves_like 'apply coupon code'
    end

    context 'checkout address' do
      before do
        click_link 'checkout'
        expect(page).to have_current_path(%r{/checkout/address})
      end

      it_behaves_like 'apply coupon code'
    end

    context 'checkout delivery' do
      before do
        click_link 'checkout'
        fill_in 'order_email', with: 'test@example.com'
        fill_in_address
        click_button 'Save and Continue'
        expect(page).to have_current_path(%r{/checkout/delivery})
      end

      it_behaves_like 'apply coupon code'
    end

    context 'checkout payment' do
      before do
        click_link 'checkout'
        fill_in 'order_email', with: 'test@example.com'
        fill_in_address
        click_button 'Save and Continue'
        click_button 'Save and Continue'
        expect(page).to have_current_path(%r{/checkout/payment})
      end

      it_behaves_like 'apply coupon code'
    end
  end
end
