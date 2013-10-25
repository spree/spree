require 'spec_helper'

describe 'Payments' do
  stub_authorization!

  let!(:payment) do
    create(:payment,
      order:          order,
      amount:         order.outstanding_balance,
      payment_method: create(:bogus_payment_method),  # Credit Card
      state:          state
    )
  end

  let(:order) { create(:completed_order_with_totals, number: 'R100') }
  let(:state) { 'checkout' }

  before do
    visit spree.admin_path
    click_link 'Orders'
    within_row(1) do
      click_link order.number
    end
    click_link 'Payments'
  end

  def refresh_page
    visit current_path
  end

  it 'creates a new payment' do
    click_on 'New Payment'
    page.should have_content('New Payment')
    click_button 'Update'
    page.should have_content('successfully created!')

    click_icon(:capture)
    find('#payment_status').text.should == 'paid'

    page.should_not have_selector('#new_payment_section')
  end

  it 'voids a payment', js: true do
    find('#payment_status').text.should == 'BALANCE DUE'
    within_row(1) do
      column_text(2).should == '$50.00'
      column_text(3).should == 'Credit Card'
      column_text(4).should == 'CHECKOUT'
    end

    click_icon :void
    find('#payment_status').text.should == 'BALANCE DUE'
    page.should have_content('Payment Updated')

    within_row(1) do
      column_text(2).should == '$50.00'
      column_text(3).should == 'Credit Card'
      column_text(4).should == 'VOID'
    end
  end

  # Regression test for #1269
  it 'cannot create a payment for an order with no payment methods' do
    Spree::PaymentMethod.delete_all
    order.payments.delete_all

    click_on 'New Payment'
    page.should have_content('You cannot create a payment for an order without any payment methods defined.')
    page.should have_content('Please define some payment methods first.')
  end

  # Regression tests for #1453
  context 'with a check payment' do
    let!(:payment) do
      create(:payment,
        order:          order,
        amount:         order.outstanding_balance,
        payment_method: create(:payment_method)  # Check
      )
    end

    it 'capturing a check payment from a new order' do
      click_icon(:capture)
      page.should_not have_content('Cannot perform requested operation')
      page.should have_content('Payment Updated')
    end

    it 'voids a check payment from a new order' do
      click_icon(:void)
      page.should have_content('Payment Updated')
    end
  end

  context 'payment is pending', js: true do
    let(:state) { 'pending' }

    it 'allows the amount to be edited by clicking on the edit button then saving' do
      within_row(1) do
        click_icon(:edit)
        fill_in('amount', with: '$1')
        click_icon(:save)
        page.should have_selector('td.amount span', text: '$1.00')
        payment.reload.amount.should == 1.00
      end
    end

    it 'allows the amount to be edited by clicking on the amount then saving' do
      within_row(1) do
        find('td.amount span').click
        fill_in('amount', with: '$1.01')
        click_icon(:save)
        page.should have_selector('td.amount span', text: '$1.01')
        payment.reload.amount.should == 1.01
      end
    end

    it 'allows the amount to be edited by clicking on the amount then clicking away' do
      pending "This test fails locally and on CI as of 1st October, 2013. Cannot work out why."
      within_row(1) do
        find('td.amount span').click
        fill_in('amount', with: '$1.10')
        page.execute_script("$('td.amount input:focus').blur()")
        page.should have_selector('td.amount span', text: '$1.10')
        payment.reload.amount.should == 1.10
      end
    end

    it 'allows the amount change to be cancelled by clicking on the cancel button' do
      within_row(1) do
        click_icon(:edit)
        fill_in('amount', with: '$1')
        click_icon(:cancel)
        page.should have_selector('td.amount span', text: '$50.00')
        payment.reload.amount.should == 50.00
      end
    end

    it 'displays an error when the amount is invalid' do
      within_row(1) do
        click_icon(:edit)
        fill_in('amount', with: 'invalid')
        click_icon(:save)
        find('td.amount input').value.should == 'invalid'
        payment.reload.amount.should == 50.00
      end
      page.should have_selector('.flash.error', text: 'Invalid resource. Please fix errors and try again.')
    end
  end

  context 'payment is completed', js: true do
    let(:state) { 'completed' }

    it 'does not allow the amount to be edited' do
      within_row(1) do
        page.should_not have_selector('.icon-edit')
        page.should_not have_selector('td.amount span')
      end
    end
  end
end
