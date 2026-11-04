require 'spec_helper'

describe Spree::PaymentMethodRule, type: :model do
  it_behaves_like 'type labels'

  let(:store) { @default_store }
  let(:payment_method) { create(:check_payment_method, store: store) }
  let(:cart) { create(:cart_with_line_items, store: store, line_items_price: 20) }

  describe 'validations' do
    it 'rejects unregistered types' do
      rule = described_class.new(payment_method: payment_method)
      rule.type = 'Kernel'

      expect(rule).not_to be_valid
      expect(rule.errors[:type]).to be_present
    end

    it 'allows one instance of each rule kind per method' do
      create(:channel_payment_method_rule, payment_method: payment_method)

      expect(build(:channel_payment_method_rule, payment_method: payment_method)).not_to be_valid
    end
  end

  describe Spree::PaymentMethodRules::ChannelRule do
    let(:channel) { create(:channel, store: store) }
    let(:other_channel) { create(:channel, store: store) }

    it 'offers the method only on the listed channels and fails open when empty' do
      cart.update!(channel: channel)
      rule = described_class.new(payment_method: payment_method)
      expect(rule.eligible?(cart)).to be(true)

      rule.preferred_channel_ids = [channel.prefixed_id]
      expect(rule.eligible?(cart)).to be(true)

      rule.preferred_channel_ids = [other_channel.id]
      expect(rule.eligible?(cart)).to be(false)
    end

    it 'rejects channels of another store' do
      rule = described_class.new(payment_method: payment_method)
      foreign = create(:channel, store: create(:store))

      expect { rule.preferred_channel_ids = [foreign.id] }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe Spree::PaymentMethodRules::MarketRule do
    let(:market) { create(:market, store: store) }
    let(:other_market) { create(:market, store: store) }

    it 'offers the method only in the listed markets' do
      cart.update_columns(market_id: market.id)
      rule = described_class.new(payment_method: payment_method, preferred_market_ids: [market.id])
      expect(rule.eligible?(cart)).to be(true)

      rule.preferred_market_ids = [other_market.id]
      expect(rule.eligible?(cart)).to be(false)
    end
  end

  describe Spree::PaymentMethodRules::OrderTotalRule do
    it 'bounds the total inclusively, per currency' do
      rule = described_class.new(payment_method: payment_method)
      expect(rule.eligible?(cart)).to be(true)

      rule.preferred_min_totals = { 'USD' => cart.total.to_s }
      expect(rule.eligible?(cart)).to be(true)

      rule.preferred_min_totals = { 'USD' => (cart.total + 1).to_s }
      expect(rule.eligible?(cart)).to be(false)

      rule.preferred_min_totals = {}
      rule.preferred_max_totals = { 'USD' => (cart.total - 1).to_s }
      expect(rule.eligible?(cart)).to be(false)
    end

    it 'refuses a minimum above the maximum in one currency' do
      rule = described_class.new(payment_method: payment_method,
                                 preferred_min_totals: { 'USD' => '500' }, preferred_max_totals: { 'USD' => '100' })

      expect(rule).not_to be_valid
      expect(rule.errors.full_messages.join).to include('USD')
    end

    it 'leaves a currency with no threshold unrestricted' do
      rule = described_class.new(payment_method: payment_method, preferred_min_totals: { 'EUR' => '5000' })

      expect(rule.eligible?(cart)).to be(true)
    end
  end

  describe Spree::PaymentMethodRules::CustomerGroupRule do
    let(:group) { create(:customer_group, store: store) }
    let(:customer) { create(:customer) }

    it 'offers the method only to members of the listed groups, never to guests' do
      rule = described_class.new(payment_method: payment_method, preferred_customer_group_ids: [group.id])
      expect(rule.eligible?(cart)).to be(false)

      cart.update!(customer: customer)
      expect(rule.eligible?(cart)).to be(false)

      group.add_customers([customer.id])
      expect(rule.eligible?(cart)).to be(true)
    end
  end

  describe Spree::PaymentMethodRules::CompanyRule do
    let(:company) { create(:company, store: store) }
    let(:division) { create(:company_division, store: store, parent: company) }
    let(:other_company) { create(:company, store: store) }

    it 'requires a company purchase when no companies are listed' do
      rule = described_class.new(payment_method: payment_method)
      expect(rule.eligible?(cart)).to be(false)

      cart.update_columns(company_id: company.id)
      expect(rule.eligible?(cart.reload)).to be(true)

      rule.preferred_company_orders_only = false
      cart.update_columns(company_id: nil)
      expect(rule.eligible?(cart.reload)).to be(true)
    end

    it 'reads the company a sole membership resolves to' do
      cart.update!(customer: create(:customer))
      create(:company_membership, company: division, customer: cart.customer)
      rule = described_class.new(payment_method: payment_method, preferred_company_ids: [company.id])

      expect(rule.eligible?(cart.reload)).to be(true)
    end

    it 'matches a listed company or any company above the purchase' do
      rule = described_class.new(payment_method: payment_method, preferred_company_ids: [company.id])
      cart.update_columns(company_id: division.id)
      expect(rule.eligible?(cart.reload)).to be(true)

      rule.preferred_company_ids = [other_company.id]
      expect(rule.eligible?(cart)).to be(false)
    end
  end
end
