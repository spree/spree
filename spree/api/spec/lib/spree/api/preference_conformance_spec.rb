require 'spec_helper'
require Spree::Api::Engine.root.join('lib/spree/api/preference_families').to_s

# The preferences contract every configurable type keeps, read the way the API
# reads it (`Masking.serialize`) and written the way the API writes it
# (`assign_preferences`). A second implementation of the API must pass the
# same checks.
RSpec.describe 'Preference contract conformance' do
  Spree::Api::PreferenceFamilies::REGISTRIES.each do |family, registry|
    describe family do
      let(:classes) { registry.call.map { |entry| entry.is_a?(Class) ? entry : entry.to_s.constantize }.uniq }

      it 'publishes a valid schema that a new record of each type satisfies' do
        classes.each do |klass|
          schema = klass.preference_json_schema
          expect(JSONSchemer.valid_schema?(schema)).to be(true), "#{klass.name} has an invalid schema"

          errors = JSONSchemer.schema(schema).validate(Spree::Preferences::Masking.serialize(klass.new)).map { |error| error['error'] }
          expect(errors).to be_empty, "#{klass.name}: #{errors.join('; ')}"
        end
      end

      it 'refuses a key the schema does not list' do
        classes.each do |klass|
          expect { klass.new.assign_preferences('not_a_setting' => 'x') }
            .to raise_error(Spree::Preferences::InvalidPreferences), "#{klass.name} accepted an unknown key"
        end
      end

      it 'refuses an id of another model in every id list' do
        classes.each do |klass|
          klass.preference_json_schema['properties'].each do |key, property|
            next unless property.dig('items', 'format') == 'prefixed-id'

            expect { klass.new.assign_preferences(key => ['zz_86Rf07xd4z']) }
              .to raise_error(Spree::Preferences::InvalidPreferences, %r{/preferences/#{key}/0}), "#{klass.name}##{key} accepted a foreign id"
          end
        end
      end

      it 'keeps a secret sent back masked, and clears it on null' do
        classes.each do |klass|
          klass.preference_json_schema['properties'].each do |key, property|
            next unless property['x-spree-secret']

            record = klass.new
            record.set_preference(key, 'sk_test_0123456789')
            masked = Spree::Preferences::Masking.serialize(record)[key]

            record.assign_preferences(key => masked)
            expect(record.get_preference(key)).to eq('sk_test_0123456789'), "#{klass.name}##{key} overwrote a secret with its mask"

            record.assign_preferences(key => nil)
            expect(Spree::Preferences::Masking.serialize(record)[key]).to be_nil, "#{klass.name}##{key} kept a secret set to null"
          end
        end
      end
    end
  end
end
