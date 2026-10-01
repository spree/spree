# Typed model preferences, each a Rails store accessor on the `preferences`
# JSON column — `secret_preferences` for a `:password` one (see
# {Spree::SecretPreferences}). Included by `Spree::Base`.
#
#   class Settings < Spree::Base
#     preference :color,       :string,  default: 'red'
#     preference :temperature, :integer, default: 21
#   end
#
#   s = Settings.new
#   s.preferred_color                # => 'red'
#   s.preferred_temperature = '24'   # cast on assignment
#   s.preferred_temperature          # => 24
#   s.preferences                    # => { 'color' => 'red', 'temperature' => 24 }

require 'spree/core/preferences/preferable_class_methods'

module Spree::Preferences::Preferable
  extend ActiveSupport::Concern

  included do
    serialize :preferences, coder: Spree::Metadata::HashSerializer
    extend Spree::Preferences::PreferableClassMethods
  end

  def get_preference(name)
    has_preference! name
    public_send(:"preferred_#{name}")
  end

  def set_preference(name, value)
    has_preference! name
    public_send(:"preferred_#{name}=", value)
  end

  def preference_type(name)
    preference_definition(name)[:type]
  end

  def preference_default(name)
    instance_exec(&preference_definition(name)[:default])
  end

  def preference_deprecated(name)
    preference_definition(name)[:deprecated]
  end

  # Whether this preference is written by Spree rather than supplied by the
  # operator — a webhook secret a provider issues, say. Kept out of the
  # schema, so nothing offers it as a field to fill in.
  def preference_internal(name)
    preference_definition(name)[:internal]
  end

  # The fixed set this preference's value must come from, when it has one.
  # Carried into the schema so an admin form renders a picker rather than a
  # text box the operator can only get wrong.
  #
  # @return [Array, nil]
  def preference_choices(name)
    choices = preference_definition(name)[:choices]
    choices.respond_to?(:call) ? choices.call : choices
  end

  def has_preference!(name)
    raise NoMethodError, "#{name} preference not defined" unless has_preference? name
  end

  def has_preference?(name)
    self.class.preference_definitions.key?(name.to_sym)
  end

  def defined_preferences
    self.class.preference_definitions.keys
  end

  def default_preferences
    defined_preferences.index_with { |name| preference_default(name) }
  end

  # Every preference value, secrets included — what `preferences` alone held
  # before secrets moved to their own column. Secrets read through their
  # `preferred_*` reader, so a default applies.
  #
  # @return [ActiveSupport::HashWithIndifferentAccess]
  def preference_values
    (preferences || {}).to_h.with_indifferent_access.merge(
      self.class.secret_preference_names.index_with { |name| get_preference(name) }
    )
  end

  # The stored value of a preference, before its default applies. A secret
  # found in `preferences` wins over the encrypted column: it is either a
  # newer value assigned as part of a whole hash, waiting for the save that
  # moves it across, or one the upgrade has not moved yet — the writer always
  # removes that copy, so it is never stale.
  #
  # @param name [Symbol, String]
  # @return [Object] the stored value, or the block's result when nothing is stored
  def stored_preference(name)
    if secret_preference?(name)
      (preferences || {}).fetch(name) { (secret_preferences || {}).fetch(name) { return yield } }
    else
      (preferences || {}).fetch(name) { yield }
    end
  end

  # Fills in the declared default of every preference this record has no
  # stored value for, so a preference added to the class after the row was
  # saved never reads as missing and the raw `preferences` hash always holds
  # every value. Secrets are left out: their defaults are read through the
  # `preferred_*` reader, never copied into storage.
  def backfill_default_preferences
    secrets = self.class.secret_preference_names
    missing = default_preferences.reject { |name, _| preferences.key?(name) || secrets.include?(name) }
    self.preferences = preferences.merge(missing) if missing.any?
  end

  # Names of the preferences the last save changed, secrets included.
  #
  # @return [Array<Symbol>]
  def previously_changed_preference_names
    defined_preferences.select { |name| public_send(:"saved_change_to_preferred_#{name}?") }
  end

  private

  def preference_definition(name)
    has_preference! name
    self.class.preference_definitions[name.to_sym]
  end

  # Only a class that stores secrets can declare one, so the names say it all.
  def secret_preference?(name)
    self.class.secret_preference_names.include?(name.to_sym)
  end

  def cast_preference(name, value)
    definition = preference_definition(name)
    parse_on_set = definition[:parse_on_set]
    if parse_on_set.is_a?(Proc)
      # Procs that accept more than one arg opt into receiving the owning
      # record so they can scope (e.g. `normalize_id_preference` rejecting
      # cross-store IDs). `arity.abs > 1` covers both the `(value, owner)` and
      # `(value, owner = nil)` shapes.
      value = parse_on_set.arity.abs > 1 ? parse_on_set.call(value, self) : parse_on_set.call(value)
    end
    value = convert_preference_value(value, definition[:type], nullable: definition[:nullable])
    # Decimals and times are kept in the string form JSON stores, so a record
    # read back from the database and one just written compare equal and
    # setting the same value is not a change. The reader restores them.
    value = value.as_json if %i[decimal datetime].include?(definition[:type])

    Spree::Deprecation.warn("`#{name}` is deprecated. #{definition[:deprecated]}") if definition[:deprecated]
    value
  end

  # Assigns a new hash rather than calling the store accessor's writer, which
  # skips writing nil to a missing key — leaving the default in force when nil
  # was meant. Rails still sees no change when the value is the one stored.
  def write_preference(name, value)
    if secret_preference?(name)
      # A copy assigned as part of a whole hash would otherwise outlive the
      # value written here and be moved over it on save.
      self.preferences = preferences.except(name) if preferences&.key?(name)
      self.secret_preferences = (secret_preferences || {}).with_indifferent_access.merge(name => value)
    else
      self.preferences = (preferences || {}).with_indifferent_access.merge(name => value)
    end
  end

  def restore_preference_value(value, type)
    return value unless value.is_a?(String)

    case type
    when :decimal then value.to_d
    when :datetime then Time.zone.iso8601(value)
    else value
    end
  rescue ArgumentError
    value
  end

  def convert_preference_value(value, type, nullable: false)
    case type
    when :string, :text
      # A nullable string keeps "unset" (nil / empty string) as nil so it can
      # fall back to another value, instead of collapsing it to "".
      if nullable && (value.nil? || (value.respond_to?(:empty?) && value.empty?))
        nil
      else
        value.to_s
      end
    when :password
      value.to_s
    when :decimal
      decimal_value = value.presence
      decimal_value ||= 0 unless nullable
      decimal_value.present? ? decimal_value.to_s.to_d : decimal_value
    when :integer
      int_value = value.presence
      int_value ||= 0 unless nullable
      int_value.present? ? int_value.to_i : int_value
    when :boolean
      # A nullable boolean keeps "unset" (nil / empty string) as nil so it can
      # fall back to another value, instead of collapsing it to false. An
      # explicit false is preserved (it is neither nil nor empty).
      if nullable && (value.nil? || (value.respond_to?(:empty?) && value.empty?))
        nil
      elsif value.is_a?(FalseClass) ||
          value.nil? ||
          value == 0 ||
          value&.to_s =~ /^(f|false|0)$/i ||
          (value.respond_to?(:empty?) && value.empty?)
        false
      else
        true
      end
    when :array
      value.is_a?(Array) ? value : Array.wrap(value)
    when :hash
      case value.class.to_s
      when 'Hash'
        value
      when 'ActionController::Parameters'
        value.to_h
      when 'String'
        # only works with hashes whose keys are strings
        JSON.parse value.gsub('=>', ':')
      when 'Array'
        begin
          value.try(:to_h)
        rescue TypeError
          Hash[*value]
        rescue ArgumentError
          raise 'An even count is required when passing an array to be converted to a hash'
        end
      else
        value.class.ancestors.include?(Hash) ? value : {}
      end
    when :datetime
      return nil if value.blank?

      case value
      when Time, Date, DateTime, ActiveSupport::TimeWithZone
        value
      when String
        Time.zone.parse(value)
      else
        value.to_time
      end
    # Kept as the `yyyy-MM-dd` string it arrived as rather than coerced to a
    # Time. Preferences are stored as JSON, and what a date *means* depends on
    # the store's timezone, which this method has no access to: coercing here
    # would freeze the value against the server's zone and move the operator's
    # deadline by hours. The reader owns that (see
    # `Spree::SellerRequirements::AcceptTerms#effective_from`); the type exists
    # so the admin form knows to render a date picker.
    when :date
      return nil if value.blank?

      case value
      when Date, Time, DateTime, ActiveSupport::TimeWithZone
        value.strftime('%Y-%m-%d')
      else
        value.to_s
      end
    else
      value
    end
  end
end
