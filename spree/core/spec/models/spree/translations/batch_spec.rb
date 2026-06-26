require 'spec_helper'

RSpec.describe Spree::Translations::Batch do
  let(:store) { @default_store }
  let!(:option_type) { create(:option_type, name: 'size', presentation: 'Size') }
  let!(:option_value) { create(:option_value, name: 'small', presentation: 'Small', option_type: option_type) }

  before do
    store.update!(supported_locales: 'en,de,fr')
    allow(Spree::Current).to receive(:store).and_return(store)
  end

  def entry(type, record, values)
    { resource_type: type, resource_id: record.prefixed_id, values: values }
  end

  describe '#process!' do
    it 'upserts every entry and returns the written records' do
      batch = described_class.new([
        entry('option_type', option_type, 'de' => { 'label' => 'Größe' }),
        entry('option_value', option_value, 'de' => { 'label' => 'Klein' })
      ])

      records = batch.process!

      expect(records).to contain_exactly(option_type, option_value)
      Mobility.with_locale(:de) do
        expect(option_type.reload.presentation).to eq('Größe')
        expect(option_value.reload.presentation).to eq('Klein')
      end
    end

    it 'is atomic: an invalid entry rolls back earlier writes' do
      batch = described_class.new([
        entry('option_type', option_type, 'de' => { 'label' => 'Größe' }),
        # unsupported locale → raises, must roll back the option_type write
        entry('option_value', option_value, 'es' => { 'label' => 'Pequeño' })
      ])

      expect { batch.process! }.to raise_error(described_class::EntryError) { |e| expect(e.index).to eq(1) }
      # The de write rolled back — no German translation persisted.
      Mobility.with_locale(:de) { expect(option_type.reload.presentation(fallback: false)).to be_nil }
      expect(option_type.presentation).to eq('Size')
    end

    it 'raises EntryError with the index for an unknown resource type' do
      batch = described_class.new([{ resource_type: 'unicorn', resource_id: 'u_1', values: {} }])

      expect { batch.process! }.to raise_error(described_class::EntryError) { |e| expect(e.index).to eq(0) }
    end

    it 'raises EntryError for a record missing in the current store' do
      batch = described_class.new([{ resource_type: 'option_type', resource_id: 'opt_NotReal', values: {} }])

      expect { batch.process! }.to raise_error(described_class::EntryError)
    end

    it 'raises EmptyError when there are no entries' do
      expect { described_class.new([]).process! }.to raise_error(described_class::EmptyError)
    end

    it 'yields each resolved record before writing so the caller can authorize' do
      batch = described_class.new([entry('option_type', option_type, 'de' => { 'label' => 'Größe' })])

      expect { |b| batch.process!(&b) }.to yield_with_args(option_type)
    end
  end

  describe '#required_scopes' do
    it 'returns one write_<resource> scope per distinct resource type' do
      batch = described_class.new([
        entry('option_type', option_type, {}),
        entry('option_value', option_value, {}),
        entry('option_type', option_type, {})
      ])

      expect(batch.required_scopes).to contain_exactly('write_option_types', 'write_option_values')
    end
  end
end
