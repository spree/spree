require 'spec_helper'

describe 'Coupon code promotions', type: :feature, js: true do
  before { create(:store, default: true) }

  let!(:country)         { create(:country)                 }
  let!(:state)           { create(:state, country: country) }
  let!(:zone)            { create(:zone)                    }
  let!(:shipping_method) { create(:shipping_method)         }
  let!(:payment_method)  { create(:check_payment_method)    }
  let!(:product)         { create(:product, price: 20)      }
  let!(:other_product)   { create(:product, price: 10)      }
  let(:address)          { build(:address, state: state)    }
  let(:coupon_code)      { 'some-coupon-code'               }

  context 'visitor makes checkout as guest without registration' do
    let!(:promotion) do
      promotion = create(
        :promotion,
        name:       coupon_code.titleize,
        code:       coupon_code,
        starts_at:  1.day.ago,
        expires_at: 1.day.from_now
      )

      Spree::Promotion::Actions::CreateItemAdjustments.create!(
        calculator: Spree::Calculator::FlatRate.new(preferred_amount: 10),
        promotion:  promotion
      )

      promotion.reload # so that promotion.actions is available
    end

    # OrdersController
    context 'on the payment page' do
      before do
        visit spree.root_path
        click_link product.name
        click_button 'add-to-cart-button'
        click_button 'Checkout'
        fill_in 'order_email', with: 'spree@example.com'
        fill_in_address_form('order_bill_address_attributes', address)

        # To shipping method screen
        click_button 'Save and Continue'
        # To payment screen
        click_button 'Save and Continue'
      end

      it 'informs about an invalid coupon code' do
        fill_in 'order_coupon_code', with: 'coupon_codes_rule_man'
        click_button 'Save and Continue'
        expect(page).to have_content(Spree.t(:coupon_code_not_found))
      end

      it 'can enter an invalid coupon code, then a real one' do
        fill_in 'order_coupon_code', with: 'coupon_codes_rule_man'
        click_button 'Save and Continue'
        expect(page).to have_content(Spree.t(:coupon_code_not_found))
        fill_in 'order_coupon_code', with: coupon_code
        click_button 'Save and Continue'
        expect(page).to have_content("Promotion (#{promotion.name})   -$10.00")
      end

      context 'with a promotion' do
        it 'applies a promotion to an order' do
          fill_in 'order_coupon_code', with: coupon_code
          click_button 'Save and Continue'
          expect(page).to have_content("Promotion (#{promotion.name})   -$10.00")
        end
      end
    end

    # CheckoutController
    context 'on the cart page' do
      before do
        visit spree.root_path
        click_link product.name
        click_button 'add-to-cart-button'
      end

      it 'can enter a coupon code and receives success notification' do
        fill_in 'order_coupon_code', with: coupon_code
        click_button 'Update'
        expect(page).to have_content(Spree.t(:coupon_code_applied))
      end

      it 'can enter a promotion code with both upper and lower case letters' do
        fill_in 'order_coupon_code', with: coupon_code.capitalize
        click_button 'Update'
        expect(page).to have_content(Spree.t(:coupon_code_applied))
      end

      it 'informs the user about a coupon code which has exceeded its usage' do
        promotion.update_attributes!(usage_limit: 5)
        allow_any_instance_of(promotion.class).to receive_messages(credits_count: 10)

        fill_in 'order_coupon_code', with: coupon_code
        click_button 'Update'
        expect(page).to have_content(Spree.t(:coupon_code_max_usage))
      end

      context 'informs the user if the coupon code is not eligible' do
        before do
          rule = Spree::Promotion::Rules::ItemTotal.new
          rule.promotion = promotion
          rule.preferred_amount_min = 100
          rule.save!
        end

        specify do
          visit spree.cart_path

          fill_in 'order_coupon_code', with: coupon_code
          click_button 'Update'

          expect(page).to have_content(
            Spree.t(
              :item_total_less_than_or_equal,
              scope:  %i[eligibility_errors messages],
              amount: '$100.00'
            )
          )
        end
      end

      it 'informs the user if the coupon is expired' do
        promotion.expires_at = Date.today.beginning_of_week
        promotion.starts_at = Date.today.beginning_of_week.advance(:day => 3)
        promotion.save!
        fill_in 'order_coupon_code', with: coupon_code
        click_button 'Update'
        expect(page).to have_content(Spree.t(:coupon_code_expired))
      end

      context 'calculates the correct amount of money saved with flat percent promotions' do
        before do
          calculator = Spree::Calculator::FlatPercentItemTotal.new
          calculator.preferred_flat_percent = 20
          promotion.actions.first!.calculator = calculator
          promotion.save!
        end

        specify do
          visit spree.root_path
          click_link other_product.name
          click_button 'add-to-cart-button'

          visit spree.cart_path
          fill_in 'order_coupon_code', with: coupon_code
          click_button 'Update'

          fill_in 'order_line_items_attributes_0_quantity', with: 2
          fill_in 'order_line_items_attributes_1_quantity', with: 2
          click_button 'Update'

          within '#cart_adjustments' do
            # 20% of $40 = 8
            # 20% of $20 = 4
            # Therefore: promotion discount amount is $12.
            expect(page).to have_content("Promotion (#{promotion.name}) -$12.00")
          end

          within '.cart-total' do
            expect(page).to have_content('$48.00')
          end
        end
      end

      context 'calculates the correct amount of money saved with flat 100% promotions on the whole order' do
        before do
          calculator = Spree::Calculator::FlatPercentItemTotal.new
          calculator.preferred_flat_percent = 100

          action = Spree::Promotion::Actions::CreateAdjustment.new
          action.calculator = calculator
          action.promotion = promotion
          action.save!

          promotion.promotion_actions = [action]
          promotion.save!
        end

        specify do
          visit spree.root_path
          click_link other_product.name
          click_button 'add-to-cart-button'

          visit spree.cart_path

          within '.cart-total' do
            expect(page).to have_content('$30.00')
          end

          fill_in 'order_coupon_code', with: coupon_code
          click_button 'Update'

          within '#cart_adjustments' do
            expect(page).to have_content("Promotion (#{promotion.name}) -$30.00")
          end

          within '.cart-total' do
            expect(page).to have_content('$0.00')
          end

          quantity_inputs = find_all('input.line_item_quantity')
          # Capybara::Result#fetch does not exist so we have to use weaker #[]
          quantity_inputs[0].set(2)
          quantity_inputs[1].set(2)

          click_button 'Update'

          within '#cart_adjustments' do
            expect(page).to have_content("Promotion (#{promotion.name}) -$60.00")
          end

          within '.cart-total' do
            expect(page).to have_content('$0.00')
          end
        end
      end
    end
  end
end
