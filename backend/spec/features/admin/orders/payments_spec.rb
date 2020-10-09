require 'spec_helper'

describe 'Payments', type: :feature, js: true do
  stub_authorization!

  context 'with a pre-existing payment' do
    let!(:payment) do
      create(:payment,
             order: order,
             amount: order.outstanding_balance,
             payment_method: create(:credit_card_payment_method),
             state: state)
    end

    let(:order) { create(:completed_order_with_totals, number: 'R100', line_items_count: 5) }
    let(:state) { 'checkout' }

    before do
      visit spree.edit_admin_order_path(order)
      click_link 'Payments'
    end

    # Regression tests for #1453
    context 'with a check payment' do
      let(:order) { create(:completed_order_with_totals, number: 'R100') }

      let!(:payment) do
        create(:payment,
               order: order,
               amount: order.outstanding_balance,
               payment_method: create(:check_payment_method)) # Check
      end

      it 'capturing a check payment from a new order' do
        click_icon(:capture)
        expect(page).not_to have_content('Cannot perform requested operation')
        expect(page).to have_content('Payment Updated')
      end

      it 'voids a check payment from a new order' do
        click_icon(:void)
        expect(page).to have_content('Payment Updated')
      end
    end

    it 'lists all captures for a payment' do
      Spree::ShippingMethod.delete_all
      capture_amount = order.outstanding_balance / 2 * 100
      payment.capture!(capture_amount)

      visit spree.admin_order_payment_path(order, payment)
      expect(page).to have_content 'Capture events'
      within '#capture_events' do
        within_row(1) do
          expect(page).to have_content(capture_amount / 100)
        end
      end
    end

    it 'lists and create payments for an order' do
      within_row(1) do
        expect(column_text(3)).to eq('$150.00')
        expect(column_text(4)).to eq('Credit Card')
        expect(column_text(6)).to eq('checkout')
      end

      click_icon :void
      expect(page).to have_css('#payment_status', exact_text: 'balance due')
      expect(page).to have_content('Payment Updated')

      within_row(1) do
        expect(column_text(3)).to eq('$150.00')
        expect(column_text(4)).to eq('Credit Card')
        expect(column_text(6)).to eq('void')
      end
      within find('#contentHeader') do
        click_on 'New Payment'
      end
      expect(page).to have_content('New Payment')
      click_button 'Update'
      expect(page).to have_content('successfully created!')

      click_icon(:capture)

      expect(page).to have_css('#payment_status', exact_text: 'paid')
      expect(page).not_to have_selector('#new_payment_section')
    end

    # Regression test for #1269
    it 'cannot create a payment for an order with no payment methods', js: false do
      Spree::PaymentMethod.delete_all
      order.payments.delete_all
      within find('#contentHeader') do
        click_on 'New Payment'
      end

      expect(page).to have_content('You cannot create a payment for an order without any payment methods defined.')
      expect(page).to have_content('Please define some payment methods first.')
    end

    %w[checkout pending].each do |state|
      context "payment is #{state.inspect}" do
        let(:state) { state }

        it 'allows the amount to be edited by clicking on the edit button then saving' do
          within_row(1) do
            click_icon(:edit)
            fill_in('amount', with: '$1')
            click_icon(:save)
            expect(page).to have_selector('td.amount span', text: '$1.00')
            expect(payment.reload.amount).to eq(1.00)
          end
        end

        it 'allows the amount to be edited by clicking on the amount then saving' do
          within_row(1) do
            find('td.amount span').click
            fill_in('amount', with: '$1.01')
            click_icon(:save)
            expect(page).to have_selector('td.amount span', text: '$1.01')
            expect(payment.reload.amount).to eq(1.01)
          end
        end

        it 'allows the amount change to be cancelled by clicking on the cancel button' do
          within_row(1) do
            click_icon(:edit)

            find('td.amount input').send_keys([:backspace] * 6, '$1')

            click_icon(:cancel)
            expect(page).to have_selector('td.amount span', text: '$150.00')
            expect(payment.reload.amount).to eq(150.00)
          end
        end

        it 'displays an error when the amount is invalid' do
          within_row(1) do
            click_icon(:edit)
            fill_in('amount', with: 'invalid')
            click_icon(:save)
          end

          expect(page).to have_selector('.alert-error', text: 'Invalid resource. Please fix errors and try again.')
          expect(page).to have_field('amount', with: 'invalid')
          expect(payment.reload.amount).to eq(150.00)
        end
      end
    end

    context 'payment is completed', js: false do
      let(:state) { 'completed' }

      it 'does not allow the amount to be edited' do
        within_row(1) do
          expect(page).not_to have_selector('td.amount span')
        end
      end
    end
  end

  context 'with no prior payments' do
    let(:order) { create(:order_with_line_items, line_items_count: 1) }
    let!(:payment_method) { create(:credit_card_payment_method) }

    # Regression tests for #4129
    context 'with a credit card payment method' do
      before do
        visit spree.admin_order_payments_path(order)
      end

      it 'is able to create a new credit card payment with valid information' do
        fill_in 'Card Number', with: '4111 1111 1111 1111'
        fill_in 'Name', with: 'Test User'
        fill_in 'Expiration', with: "09 / #{Time.current.year + 1}"
        fill_in 'Card Varification Code (CVC)', with: '007'
        # Regression test for #4277
        expect(page).to have_field(class: 'ccType', type: :hidden, with: 'visa')
        click_button 'Continue'
        expect(page).to have_content('Payment has been successfully created!')
      end

      it 'is unable to create a new payment with invalid information' do
        click_button 'Continue'
        expect(page).to have_content('Payment could not be created.')
        expect(page).to have_content("Number can't be blank")
        expect(page).to have_content("Name can't be blank")
        expect(page).to have_content("Verification Value can't be blank")
        expect(page).to have_content('Month is not a number')
        expect(page).to have_content('Year is not a number')
      end
    end

    context 'user existing card' do
      let!(:cc) do
        create(:credit_card, user_id: order.user_id, payment_method: payment_method, gateway_customer_profile_id: 'BGS-RFRE')
      end

      before { visit spree.admin_order_payments_path(order) }

      it 'is able to reuse customer payment source', js: false do
        expect(page).to have_checked_field(id: "card_#{cc.id}")
        click_button 'Continue'
        expect(page).to have_content('Payment has been successfully created!')
      end
    end

    context 'with a check' do
      let!(:payment_method) { create(:check_payment_method) }

      before do
        visit spree.admin_order_payments_path(order.reload)
      end

      it 'can successfully be created and captured' do
        click_on 'Continue'
        expect(page).to have_content('Payment has been successfully created!')
        click_icon(:capture)
        expect(page).to have_content('Payment Updated')
      end
    end

    context 'store_credit payment' do
      let!(:payment_method) { create(:store_credit_payment_method) }
      let!(:category) { create(:store_credit_category, name: 'Default') }

      before do
        create(:store_credit, user: order.user, category: category, amount: 500)
        visit spree.new_admin_order_payment_path(order.reload)
        choose("payment_payment_method_id_#{payment_method.id}")
        click_button 'Continue'
      end

      it { expect(page).to have_content('successfully created') }
    end
  end
end
