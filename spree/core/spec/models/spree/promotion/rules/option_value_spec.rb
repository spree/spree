require 'spec_helper'

describe Spree::Promotion::Rules::OptionValue do
  let(:rule) { described_class.new }

  describe 'setting eligible values' do
    let(:option_value) { create(:option_value) }

    it 'accepts prefixed option value ids' do
      rule.preferred_eligible_values = [option_value.prefixed_id]
      expect(rule.preferred_eligible_values).to eq([option_value.id.to_s])
    end

    it 'rejects unknown ids' do
      expect {
        rule.preferred_eligible_values = ['optval_missing']
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '#applicable?' do
    subject { rule.applicable?(promotable) }

    context 'when promotable is an order' do
      let(:promotable) { Spree::Order.new }

      it { is_expected.to be true }
    end

    context 'when promotable is not an order' do
      let(:promotable) { Spree::LineItem.new }

      it { is_expected.to be false }
    end
  end

  describe '#eligible?' do
    subject { rule.eligible?(promotable) }

    let(:variant) { create :variant }
    let(:line_item) { create :line_item, variant: variant }
    let(:promotable) { line_item.order }

    context 'when there are any applicable line items' do
      before do
        rule.preferred_eligible_values = [variant.option_values.first.id]
      end

      it { is_expected.to be true }
    end

    context 'when there are no applicable line items' do
      let(:other_option_value) { create(:option_value) }

      before do
        rule.preferred_eligible_values = [other_option_value.id]
      end

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
        label: 'Blue',
        option_type: create(
          :option_type,
          name: 'foo-colour',
          label: 'Colour'
        )
      )
    end

    before do
      line_item.variant.option_values << option_value_blue
      rule.preferred_eligible_values = eligible_option_value_ids
    end

    context 'when the line item variant carries a matching option value' do
      let(:eligible_option_value_ids) { [option_value_blue.id] }

      it { is_expected.to be true }
    end

    context 'when the line item variant does not carry a matching option value' do
      let(:eligible_option_value_ids) { [create(:option_value).id] }

      it { is_expected.to be false }
    end
  end

  describe '#option_values' do
    let(:option_value) { create(:option_value) }

    before { rule.preferred_eligible_values = [option_value.id] }

    it 'returns the configured option values' do
      expect(rule.option_values).to contain_exactly(option_value)
    end
  end
end
