require 'spec_helper'

describe Spree::CustomFields::Date, type: :model do
  let(:product) { create(:product) }
  let(:custom_field_definition) { create(:custom_field_definition, :date_field) }

  def custom_field(value)
    described_class.new(custom_field_definition: custom_field_definition, value: value, resource: product)
  end

  it 'stores an ISO 8601 date as YYYY-MM-DD' do
    expect(custom_field('2026-10-12').tap(&:valid?).value).to eq('2026-10-12')
    expect(custom_field(Date.new(2026, 10, 12)).tap(&:valid?).value).to eq('2026-10-12')
  end

  it 'refuses anything that is not an ISO 8601 date' do
    field = custom_field('12/10/2026')

    expect(field).not_to be_valid
    expect(field.errors[:value]).to include(I18n.t('spree.errors.messages.custom_field_invalid_date'))
  end

  it 'checks the date against min and max' do
    custom_field_definition.update!(validations: { min: '2026-01-01', max: '2026-12-31' })

    expect(custom_field('2026-06-01')).to be_valid
    expect(custom_field('2025-12-31')).not_to be_valid
    expect(custom_field('2027-01-01')).not_to be_valid
  end
end
