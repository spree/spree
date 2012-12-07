require 'spec_helper'

describe 'orders' do
  let(:order) { OrderWalkthrough.up_to(:complete) }

  it "can visit an order" do
    # Regression test for current_user call on orders/show
    lambda { visit spree.order_path(order) }.should_not raise_error
  end

  it "should have credit card info if paid with credit card" do
    create(:payment, :order => order)
    visit spree.order_path(order)
    within '.payment-info' do
      page.should have_content "Ending in 1111"
    end
  end

  it "should have payment method name visible if not paid with credit card" do
    create(:check_payment, :order => order)
    visit spree.order_path(order)
    within '.payment-info' do
      page.should have_content "Check"
    end
  end

  # Regression test for #2282
  context "can support a credit card with blank information" do
    before do
      credit_card = Factory(:credit_card)
      credit_card.update_column(:cc_type, '')
      payment = order.payments.first
      payment.source = credit_card
      payment.save!
    end

    specify do
      visit spree.order_path(order)
      within '.payment-info' do
        lambda { find("img") }.should raise_error(Capybara::ElementNotFound)
      end
    end
  end
end
