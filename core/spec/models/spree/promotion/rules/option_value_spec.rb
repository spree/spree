require 'spec_helper'

describe Spree::Promotion::Rules::OptionValue do
  let(:rule) { described_class.new }

  describe 'setting eligible values' do
    let(:option_value_variant_ids) do
      [
        'abc-123',
        'def-123, def-456,ghj-789 ,   '
      ]
    end

    it 'parses ids' do
      rule.preferred_eligible_values = option_value_variant_ids
      expect(rule.preferred_eligible_values).to eq(['abc-123', 'def-123', 'def-456', 'ghj-789'])
    end
  end

  describe '#applicable?' do
    subject { rule.applicable?(promotable) }

    context 'when promotable is an order' do
      let(:promotable) { Spree::Order.new }

      it { is_expected.to be true }
    end

    context 'when promotable is a line item' do
      let(:promotable) { Spree::LineItem.new }

      it { is_expected.to be false }

      context 'for an automatic promotion' do
        before do
          rule.promotion = build(:promotion, kind: :automatic)
        end

        it { is_expected.to be true }
      end
    end
  end

  describe '#eligible?' do
    subject { rule.eligible?(promotable) }

    let(:variant) { create :variant }
    let(:line_item) { create :line_item, variant: variant }
    let(:promotable) { line_item.order }

    context 'when there are any applicable line items' do
      before do
        rule.preferred_eligible_values = [variant.option_value_variant_ids.first, 1233542]
      end

      it { is_expected.to be true }
    end

    context 'when there are no applicable line items' do
      before do
        rule.preferred_eligible_values = [123235234, 4531236]
      end

      it { is_expected.to be false }
    end

    context 'for a line item promotable' do
      let(:promotable) { line_item }

      it { is_expected.to be false }
    end
  end

  describe '#actionable?' do
    subject { rule.actionable?(line_item) }

    let(:line_item) { create :line_item }
    let(:option_value_blue) do
      create(
        :option_value,
        name: 'Blue',
        presentation: 'Blue',
        option_type: create(
          :option_type,
          name: 'foo-colour',
          presentation: 'Colour'
        )
      )
    end
    let(:option_value_medium) do
      create(
        :option_value,
        name: 'Medium',
        presentation: 'M'
      )
    end

    before do
      line_item.variant.option_values << option_value_blue
      rule.preferred_eligible_values = option_value_variant_ids
    end

    context 'when the line item has the correct product' do
      let(:product_id) { line_item.product.id }

      context 'when all of the option values match' do
        let(:option_value_variant_ids) do
          [
            line_item.variant.option_value_variants.reload.find_by(option_value: option_value_blue).id
          ]
        end

        it { is_expected.to be true }
      end

      context 'when not all of the option values match' do
        let(:option_value_variant_ids) do
          [
            line_item.variant.option_value_variants.reload.find_by(option_value: option_value_blue).id,
            12356342
          ]
        end

        it { is_expected.to be true }
      end
    end

    context "when the line item's product doesn't match" do
      let(:option_value_variant_ids) do
        [
          12312423,
          45823843
        ]
      end

      it { is_expected.to be false }
    end
  end
end
