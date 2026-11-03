require 'spec_helper'

describe Spree::CustomFields::DateTime, type: :model do
  let(:product) { create(:product) }
  let(:custom_field_definition) { create(:custom_field_definition, :date_time_field) }

  def custom_field(value)
    described_class.new(custom_field_definition: custom_field_definition, value: value, resource: product)
  end

  it 'stores an instant in UTC' do
    expect(custom_field('2026-10-12T10:00:00+02:00').tap(&:valid?).value).to eq('2026-10-12T08:00:00Z')
  end

  it "reads a value without an offset in the store's time zone" do
    allow(custom_field_definition.store).to receive(:preferred_timezone).and_return('America/New_York')

    expect(custom_field('2026-10-12T10:00').tap(&:valid?).value).to eq('2026-10-12T14:00:00Z')
  end

  it 'refuses anything that is not an ISO 8601 date and time' do
    field = custom_field('next tuesday')

    expect(field).not_to be_valid
    expect(field.errors[:value]).to include(I18n.t('spree.errors.messages.custom_field_invalid_date_time'))
  end

  it 'checks the instant against min and max' do
    custom_field_definition.update!(validations: { min: '2026-10-12T00:00:00Z' })

    expect(custom_field('2026-10-12T00:00:00Z')).to be_valid
    expect(custom_field('2026-10-11T23:59:59Z')).not_to be_valid
  end
end
