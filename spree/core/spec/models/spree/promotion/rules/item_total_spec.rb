require 'spec_helper'

describe Spree::Promotion::Rules::ItemTotal, type: :model do
  let!(:store) { @default_store }
  let(:rule) { Spree::Promotion::Rules::ItemTotal.new }
  let(:order) { build(:order, store: store) }

  less_than_or_equal_min = "This coupon code can't be applied to orders less than or equal to $50.00."
  less_than_min = "This coupon code can't be applied to orders less than $50.00."
  higher_than_or_equal_max = "This coupon code can't be applied to orders higher than or equal to $60.00."
  higher_than_max = "This coupon code can't be applied to orders higher than $60.00."

  # [operator_min, operator_max, amount_max, item_total, expected error (nil when eligible)]
  [
    ['gt', 'lt', 60, 51, nil],
    ['gt', 'lt', 60, 50, less_than_or_equal_min],
    ['gt', 'lt', 60, 49, less_than_or_equal_min],
    ['gt', 'lt', 60, 60, higher_than_or_equal_max],
    ['gt', 'lt', 60, 61, higher_than_or_equal_max],

    ['gt', 'lte', 60, 51, nil],
    ['gt', 'lte', 60, 50, less_than_or_equal_min],
    ['gt', 'lte', 60, 49, less_than_or_equal_min],
    ['gt', 'lte', 60, 60, nil],
    ['gt', 'lte', 60, 61, higher_than_max],

    ['gte', 'lt', 60, 51, nil],
    ['gte', 'lt', 60, 50, nil],
    ['gte', 'lt', 60, 49, less_than_min],
    ['gte', 'lt', 60, 60, higher_than_or_equal_max],
    ['gte', 'lt', 60, 61, higher_than_or_equal_max],

    ['gte', 'lte', 60, 51, nil],
    ['gte', 'lte', 60, 50, nil],
    ['gte', 'lte', 60, 49, less_than_min],
    ['gte', 'lte', 60, 60, nil],
    ['gte', 'lte', 60, 61, higher_than_max],

    # No maximum amount: only the minimum applies.
    ['gt', 'lt', nil, 51, nil],
    ['gt', 'lt', nil, 50, less_than_or_equal_min],
    ['gt', 'lt', nil, 49, less_than_or_equal_min]
  ].each do |operator_min, operator_max, amount_max, item_total, expected_error|
    context "with #{operator_min} 50 / #{operator_max} #{amount_max.inspect} and an item total of #{item_total}" do
      before do
        rule.preferred_amount_min = 50
        rule.preferred_amount_max = amount_max
        rule.preferred_operator_min = operator_min
        rule.preferred_operator_max = operator_max
        allow(order).to receive_messages(item_total: item_total)
      end

      if expected_error
        it 'is not eligible and explains why' do
          expect(rule).not_to be_eligible(order)
          expect(rule.eligibility_errors.full_messages.first).to eq(expected_error)
        end
      else
        it 'is eligible' do
          expect(rule).to be_eligible(order)
        end
      end
    end
  end
end
