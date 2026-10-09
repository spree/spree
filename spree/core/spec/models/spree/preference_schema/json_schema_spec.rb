require 'spec_helper'

describe Spree::PreferenceSchema::JsonSchema do
  def property(klass, name)
    klass.preference_json_schema.fetch('properties').fetch(name.to_s)
  end

  describe '.for' do
    it 'describes a closed object, so an unknown key is refused' do
      schema = Spree::Promotion::Rules::Channel.preference_json_schema

      expect(schema).to include('type' => 'object', 'additionalProperties' => false)
      expect(schema['properties'].keys).to eq(%w[channel_ids])
    end

    it 'types an id list with the model prefix' do
      expect(property(Spree::Promotion::Rules::Channel, :channel_ids)).to eq(
        'type' => 'array',
        'items' => { 'type' => 'string', 'format' => 'prefixed-id', 'pattern' => '^ch_[A-Za-z0-9]+$', 'x-spree-prefix' => 'ch' },
        'default' => []
      )
    end

    it 'types money as an exact decimal string, nullable when it has no default' do
      expect(property(Spree::Promotion::Rules::ItemTotal, :amount_min)).to include(
        'type' => 'string', 'format' => 'money', 'pattern' => described_class::DECIMAL_PATTERN, 'default' => '100'
      )
      expect(property(Spree::Promotion::Rules::ItemTotal, :amount_max)['type']).to eq(%w[string null])
    end

    it 'types a keyed hash and a list of objects' do
      expect(property(Spree::Calculator::Shipping::FlatRate, :amounts)).to include(
        'type' => 'object',
        'propertyNames' => { 'type' => 'string', 'format' => 'currency', 'pattern' => '^[A-Z]{3}$' },
        'additionalProperties' => include('format' => 'money')
      )
      expect(property(Spree::Calculator::TieredPercent, :tiers)['items']).to include(
        'type' => 'object', 'required' => %w[threshold value], 'additionalProperties' => false
      )
    end

    it 'turns choices into an enum' do
      expect(property(Spree::Promotion::Rules::Product, :match_policy)).to include('type' => 'string', 'enum' => %w[any all none])
    end

    it 'marks a secret and never carries its default' do
      secret = property(Spree::Gateway::Bogus, :dummy_secret_key)

      expect(secret).to include('x-spree-secret' => true)
      expect(secret).not_to have_key('default')
    end

    it 'keeps a deprecated preference writable until its removal, without publishing it' do
      expect(Spree::Calculator::Shipping::FlatRate.preference_json_schema['properties']).not_to have_key('minimum_item_total')

      calculator = Spree::Calculator::Shipping::FlatRate.new
      Spree::Deprecation.silence { calculator.assign_preferences({ 'minimum_item_total' => '10' }) }
      expect(calculator.preferred_minimum_item_total).to eq(10)
    end

    it 'leaves out internal preferences' do
      expect(Spree::Store.preference_json_schema['properties']).not_to have_key('install_id')
    end
  end

  # Every class Spree ships is a contract a client may rely on: its schema
  # compiles, is valid JSON Schema, and states the full type of every value.
  describe 'the declarations Spree ships' do
    let(:classes) do
      Rails.autoloaders.main.eager_load_dir(Spree::Core::Engine.root.join('app/models').to_s)
      ObjectSpace.each_object(Class).select do |klass|
        klass.name.to_s.start_with?('Spree::') && klass.respond_to?(:preference_json_schema) && klass.preference_definitions.any?
      end
    end

    it 'compile to valid JSON Schema' do
      classes.each do |klass|
        schema = klass.preference_json_schema
        expect(schema).to be_present, "#{klass.name} compiled no schema"
        expect(JSONSchemer.valid_schema?(schema)).to be(true), "#{klass.name} compiled an invalid schema"
      end
    end

    it 'state the full type of every value' do
      incomplete = classes.flat_map do |klass|
        klass.preference_definitions.filter_map do |name, definition|
          complete = case definition[:type]
                     when :any then false
                     when :array then definition[:of].present?
                     when :hash then definition[:keys].present? && definition[:values].present?
                     else true
                     end
          "#{klass.name}##{name}" unless complete || definition[:deprecated]
        end
      end

      expect(incomplete).to be_empty
    end

    it 'validate the values a new record holds' do
      classes.each do |klass|
        next if klass.abstract_class?

        record = klass.new
        schemer = JSONSchemer.schema(klass.preference_json_schema)
        errors = schemer.validate(Spree::Preferences::Masking.serialize(record)).map { |error| error['error'] }

        expect(errors).to be_empty, "#{klass.name}: #{errors.join('; ')}"
      end
    end
  end
end
