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

  it 'should be able to list and create payment methods for an order', js: true do
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

    click_on 'New Payment'
    page.should have_content('New Payment')
    click_button 'Update'
    page.should have_content('successfully created!')

    click_icon(:capture)
    find('#payment_status').text.should == 'PAID'

    page.should_not have_selector('#new_payment_section')
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
end
