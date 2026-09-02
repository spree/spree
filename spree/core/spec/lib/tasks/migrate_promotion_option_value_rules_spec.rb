require 'spec_helper'
require 'rake'

Rake::Task.define_task(:environment)
load Spree::Core::Engine.root.join('lib', 'tasks', 'migrate_promotion_option_value_rules.rake')

describe 'spree:upgrade:migrate_promotion_option_value_rules' do
  subject { Rake::Task[task_name] }

  let(:task_name) { 'spree:upgrade:migrate_promotion_option_value_rules' }

  before { subject.reenable }

  it 'rewrites join-row ids to option value ids' do
    create_list(:option_value, 3)
    option_value = create(:option_value, name: 'Medium', label: 'Medium')
    variant = create(:variant, option_values: [option_value])
    join_row = Spree::OptionValueVariant.find_by!(variant: variant, option_value: option_value)

    rule = create(:promotion_rule_option_value)
    rule.update_columns(
      preferences: rule.preferences.merge(eligible_values: [join_row.id.to_s])
    )

    allow(Spree::OptionValue).to receive(:exists?).and_call_original
    allow(Spree::OptionValue).to receive(:exists?).with(join_row.id.to_s).and_return(false)

    subject.invoke

    expect(rule.reload.preferred_eligible_values).to eq([option_value.id.to_s])
  end

  it 'leaves rules that already store option value ids untouched' do
    option_value = create(:option_value)
    rule = create(:promotion_rule_option_value, preferred_eligible_values: [option_value.id.to_s])

    subject.invoke

    expect(rule.reload.preferred_eligible_values).to eq([option_value.id.to_s])
  end

  it 'aborts when an eligible value id cannot be resolved' do
    rule = create(:promotion_rule_option_value)
    rule.update_columns(
      preferences: rule.preferences.merge(eligible_values: ['999999999'])
    )

    expect { subject.invoke }.to raise_error(SystemExit)
    expect(rule.reload.preferred_eligible_values).to eq(['999999999'])
  end

  it 'aborts when an id matches both a join row and an option value' do
    option_value = create(:option_value, name: 'Small', label: 'Small')
    variant = create(:variant, option_values: [option_value])
    join_row = Spree::OptionValueVariant.find_by!(variant: variant, option_value: option_value)

    rule = create(:promotion_rule_option_value)
    rule.update_columns(
      preferences: rule.preferences.merge(eligible_values: [join_row.id.to_s])
    )

    allow(Spree::OptionValue).to receive(:exists?).and_call_original
    allow(Spree::OptionValue).to receive(:exists?).with(join_row.id.to_s).and_return(true)
    allow(Spree::OptionValue).to receive(:exists?).with(join_row.id).and_return(true)

    expect { subject.invoke }.to raise_error(SystemExit)
    expect(rule.reload.preferred_eligible_values).to eq([join_row.id.to_s])
  end

  it 'continues without aborting when SKIP_FAILED_ROWS is set' do
    option_value = create(:option_value, name: 'Large', label: 'Large')
    variant = create(:variant, option_values: [option_value])
    join_row = Spree::OptionValueVariant.find_by!(variant: variant, option_value: option_value)

    convertible_rule = create(:promotion_rule_option_value)
    convertible_rule.update_columns(
      preferences: convertible_rule.preferences.merge(eligible_values: [join_row.id.to_s])
    )

    allow(Spree::OptionValue).to receive(:exists?).and_call_original
    allow(Spree::OptionValue).to receive(:exists?).with(join_row.id.to_s).and_return(false)

    bad_rule = create(:promotion_rule_option_value)
    bad_rule.update_columns(
      preferences: bad_rule.preferences.merge(eligible_values: ['999999999'])
    )

    old = ENV['SKIP_FAILED_ROWS']
    ENV['SKIP_FAILED_ROWS'] = 'true'
    begin
      expect { subject.invoke }.not_to raise_error

      expect(convertible_rule.reload.preferred_eligible_values).to eq([option_value.id.to_s])
      expect(bad_rule.reload.preferred_eligible_values).to eq(['999999999'])
    ensure
      if old.nil?
        ENV.delete('SKIP_FAILED_ROWS')
      else
        ENV['SKIP_FAILED_ROWS'] = old
      end
    end
  end
end

describe Spree::PromotionOptionValueRulesMigrator do
  subject(:migrator) { described_class.new(skip_failed: skip_failed) }

  let(:skip_failed) { false }

  describe '#call' do
    it 'returns the number of converted rules via #converted' do
      option_value = create(:option_value)
      variant = create(:variant, option_values: [option_value])
      join_row = Spree::OptionValueVariant.find_by!(variant: variant, option_value: option_value)

      rule = create(:promotion_rule_option_value)
      rule.update_columns(
        preferences: rule.preferences.merge(eligible_values: [join_row.id.to_s])
      )

      allow(Spree::OptionValue).to receive(:exists?).and_call_original
      allow(Spree::OptionValue).to receive(:exists?).with(join_row.id.to_s).and_return(false)

      migrator.call

      expect(migrator.issues).to be_empty
      expect(rule.reload.preferred_eligible_values).to eq([option_value.id.to_s])
      if join_row.id.to_s == option_value.id.to_s
        expect(migrator.converted).to eq(0)
      else
        expect(migrator.converted).to eq(1)
      end
    end
  end
end
