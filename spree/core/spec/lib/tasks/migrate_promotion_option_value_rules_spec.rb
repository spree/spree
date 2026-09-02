require 'spec_helper'
require 'rake'

describe 'spree:upgrade:migrate_promotion_option_value_rules' do
  subject { Rake::Task[task_name] }

  let(:task_name) { 'spree:upgrade:migrate_promotion_option_value_rules' }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'migrate_promotion_option_value_rules.rake')
  end

  before { subject.reenable }

  it 'rewrites join-row ids to option value ids' do
    create_list(:option_value, 3)
    option_value = create(:option_value, name: 'Medium', presentation: 'Medium')
    variant = create(:variant, option_values: [option_value])
    join_row = Spree::OptionValueVariant.find_by!(variant: variant, option_value: option_value)

    rule = create(:promotion_rule_option_value)
    rule.update_columns(
      preferences: rule.preferences.merge(eligible_values: [join_row.id.to_s])
    )

    subject.invoke

    expect(rule.reload.preferred_eligible_values).to eq([option_value.id.to_s])
  end

  it 'leaves rules that already store option value ids untouched' do
    option_value = create(:option_value)
    rule = create(:promotion_rule_option_value, preferred_eligible_values: [option_value.id.to_s])

    subject.invoke

    expect(rule.reload.preferred_eligible_values).to eq([option_value.id.to_s])
  end
end
