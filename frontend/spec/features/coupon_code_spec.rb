require 'spec_helper'

describe 'Coupon code promotions', type: :feature, js: true do
  let!(:country) { create(:country, name: 'United States of America', states_required: true) }
  let!(:state) { create(:state, name: 'Alabama', country: country) }
  let!(:mug) { create(:product, name: 'RoR Mug', price: 20) }

  before do
    create(:zone)
    create(:shipping_method)
    create(:check_payment_method)
    create(:store)
  end

  context 'visitor makes checkout as guest without registration' do
    def create_basic_coupon_promotion(code)
      promotion = Spree::Promotion.create!(name: code.titleize,
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

    def apply_coupon(code)
      fill_in 'order_coupon_code', with: code
      click_button 'shopping-cart-coupon-code-button'
    end

    # OrdersController
    context 'on the payment page' do
      it 'informs about an invalid coupon code' do
        add_to_cart(mug)

        apply_coupon('coupon_codes_rule_man')
        expect(page).to have_content(Spree.t(:coupon_code_not_found))
      end

      it 'informs the user about a coupon code which has exceeded its usage' do
        add_to_cart(mug)

        promotion.update_column(:usage_limit, 5)
        allow_any_instance_of(promotion.class).to receive_messages(credits_count: 10)

        apply_coupon('onetwo')
        expect(page).to have_content(Spree.t(:coupon_code_max_usage))
      end

      it 'can enter an invalid coupon code, then a real one' do
        add_to_cart(mug)

        apply_coupon('coupon_codes_rule_man')
        expect(page).to have_content(Spree.t(:coupon_code_not_found))

        apply_coupon('onetwo')
        expect(page).to have_field('order_applied_coupon_code', with: 'Promotion (Onetwo)')
      end

      context 'with a promotion' do
        it 'applies a promotion to an order' do
          add_to_cart(mug)

          apply_coupon('onetwo')
          expect(page).to have_field('order_applied_coupon_code', with: 'Promotion (Onetwo)')
        end
      end
    end
  end
end
