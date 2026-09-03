require 'spec_helper'

describe Spree::OptionType, type: :model do
  it_behaves_like 'metadata'

  describe '#filterable' do
    it { expect(subject.filterable).to eq(true) }
  end

  describe 'callbacks' do
    describe '#normalize_name' do
      let!(:option_type) { build(:option_type, name: 'Shirt Size') }

      it 'should parameterize the name' do
        option_type.name = 'Shirt Size'
        option_type.save!
        expect(option_type.name).to eq('shirt-size')
      end
    end
  end

  describe 'translations' do
    let!(:option_type) { create(:option_type, name: 'size', label: 'Size') }

    before do
      Mobility.with_locale(:pl) do
        option_type.update!(label: 'Rozmiar')
      end
    end

    let(:option_type_pl_translation) { option_type.translations.find_by(locale: 'pl') }

    it 'translates option type fields' do
      expect(option_type.label).to eq('Size')

      expect(option_type_pl_translation).to be_present
      expect(option_type_pl_translation.label).to eq('Rozmiar')
    end

    describe '#label' do
      it 'returns the translated label for the current locale' do
        expect(option_type.label).to eq('Size')
      end

      it 'returns the translated label for a different locale' do
        Mobility.with_locale(:pl) do
          expect(option_type.label).to eq('Rozmiar')
        end
      end

      it 'sets the translated label' do
        Mobility.with_locale(:pl) do
          option_type.label = 'Nowy Rozmiar'
          option_type.save!
          expect(option_type.label).to eq('Nowy Rozmiar')
        end
      end
    end

    context 'with always_use_translations enabled' do
      before do
        Spree::Config.always_use_translations = true
      end

      after do
        Spree::Config.always_use_translations = false
        I18n.locale = :en
      end

      it 'creates option type with normalized label without NotNullViolation' do
        I18n.locale = :en
        option_type = create(:option_type, name: 'weight', label: '  Weight  ')
        expect(option_type.label).to eq('Weight')
        expect(option_type.persisted?).to be true
      end

      it 'normalizes translated labels across locales' do
        I18n.locale = :en
        option_type = create(:option_type, name: 'material', label: 'Material')

        I18n.locale = :de
        option_type.label = '  Material German  '
        option_type.save!

        expect(option_type.label).to eq('Material German')

        I18n.locale = :en
        expect(option_type.label).to eq('Material')
      end
    end
  end

  describe 'kind' do
    it 'defaults to dropdown' do
      option_type = create(:option_type)
      expect(option_type.kind).to eq('dropdown')
    end

    it 'validates inclusion in KINDS' do
      option_type = build(:option_type, kind: 'invalid')
      expect(option_type).not_to be_valid
      expect(option_type.errors[:kind]).to include('is not included in the list')
    end

    it 'allows dropdown, color_swatch, and buttons' do
      %w[dropdown color_swatch buttons].each do |kind|
        option_type = build(:option_type, kind: kind)
        expect(option_type).to be_valid
      end
    end

    it 'validates presence' do
      option_type = build(:option_type, kind: '')
      expect(option_type).not_to be_valid
    end
  end

  describe '#color_swatch?' do
    it 'returns true when kind is color_swatch' do
      option_type = build(:option_type, kind: 'color_swatch')
      expect(option_type.color_swatch?).to be true
    end

    it 'returns false when kind is dropdown' do
      option_type = build(:option_type, kind: 'dropdown')
      expect(option_type.color_swatch?).to be false
    end
  end

  context 'touching' do
    let(:option_type) { create(:option_type) }
    let(:product) { create(:product) }
    let!(:product_option_type) { create(:product_option_type, option_type: option_type, product: product) }

    before do
      product.update_column(:updated_at, 1.day.ago)
    end

    it 'touches a product on touch' do
      expect { option_type.touch }.to change { product.reload.updated_at }
    end

    it 'touches a product on update' do
      expect { option_type.update!(label: 'New Label') }.to change { product.reload.updated_at }
    end
  end

  describe '#option_values=' do
    context 'with an array of OptionValue records' do
      let(:option_type) { create(:option_type) }
      let(:option_value) { build(:option_value, option_type: option_type) }

      it 'delegates to the AR collection writer' do
        option_type.option_values = [option_value]
        expect(option_type.option_values).to eq([option_value])
      end
    end

    context 'on a new option type' do
      it 'persists option values when the parent is saved' do
        option_type = build(:option_type)
        option_type.option_values = [{ name: 'red', label: 'Red' }]

        # Children mutate the in-memory association and ride the parent's
        # save via `autosave: true` — no DB hits until `save!`.
        expect(option_type.option_values.first).not_to be_persisted
        option_type.save!
        expect(option_type.option_values.pluck(:name)).to eq(['red'])
      end
    end

    context 'on a persisted option type' do
      let!(:option_type) { create(:option_type) }
      let!(:red) { create(:option_value, option_type: option_type, name: 'red', label: 'Red', position: 1) }
      let!(:blue) { create(:option_value, option_type: option_type, name: 'blue', label: 'Blue', position: 2) }

      it 'updates existing values matched by id on save' do
        option_type.option_values = [{ id: red.prefixed_id, label: 'Bright Red' }]
        option_type.save!
        expect(red.reload.label).to eq('Bright Red')
      end

      it 'renames a value when name is sent with its id (id-based matching)' do
        option_type.option_values = [{ id: red.prefixed_id, name: 'crimson', label: 'Crimson' }]
        option_type.save!
        expect(red.reload.name).to eq('crimson')
      end

      it 'creates new values when id is absent' do
        option_type.option_values = [
          { id: red.prefixed_id, name: 'red', label: 'Red' },
          { id: blue.prefixed_id, name: 'blue', label: 'Blue' },
          { name: 'green', label: 'Green' }
        ]
        option_type.save!
        expect(option_type.reload.option_values.pluck(:name)).to match_array(%w[red blue green])
      end

      it 'destroys values not referenced in the payload' do
        option_type.option_values = [{ id: red.prefixed_id, name: 'red', label: 'Red' }]
        option_type.save!
        expect(option_type.reload.option_values.pluck(:name)).to eq(['red'])
        expect { blue.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'destroys all values when given an empty array' do
        option_type.option_values = []
        expect(option_type.reload.option_values).to be_empty
      end

      it 'leaves values untouched when the writer is not called' do
        option_type.update!(label: 'Updated')
        expect(option_type.reload.option_values.pluck(:name)).to match_array(%w[red blue])
      end

      it 'returns false from save and surfaces validation errors when option values are invalid' do
        option_type.option_values = [{ name: '', label: '' }]
        expect(option_type.save).to be false
        # Rails autosave surfaces nested errors as `option_values.<attr>`.
        expect(option_type.errors.attribute_names.map(&:to_s)).to include('option_values.name')
        # Existing rows must not be touched when the parent save fails.
        expect(option_type.reload.option_values.pluck(:name)).to match_array(%w[red blue])
      end
    end
  end

  # The pre-6.0 name stays callable for one release. It is a plain method, not
  # an alias_attribute — Mobility owns `label` — so it reads and writes on an
  # instance only.
  describe 'the deprecated presentation reader' do
    let(:option_type) { create(:option_type, label: 'Size') }

    it 'reads the label' do
      expect(Spree::Deprecation).to receive(:warn).with(/presentation is deprecated/)

      expect(option_type.presentation).to eq('Size')
    end

    it 'writes the label' do
      expect(Spree::Deprecation).to receive(:warn).with(/presentation= is deprecated/)

      option_type.presentation = 'Waist'
      expect(option_type.label).to eq('Waist')
    end
  end

end
