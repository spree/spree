# Preferable allows defining preference accessor methods.
#
# A class including Preferable must implement #preferences which should return
# an object responding to .fetch(key), []=(key, val), and .delete(key).
#
# The generated writer method performs typecasting before assignment into the
# preferences object.
#
# Examples:
#
#   # Spree::Base includes Preferable and stores preferences in a JSON
#   # column.
#   class Settings < Spree::Base
#     preference :color,       :string,  default: 'red'
#     preference :temperature, :integer, default: 21
#   end
#
#   s = Settings.new
#   s.preferred_color # => 'red'
#   s.preferred_temperature # => 21
#
#   s.preferred_color = 'blue'
#   s.preferred_color # => 'blue'
#
#   # Typecasting is performed on assignment
#   s.preferred_temperature = '24'
#   s.preferred_temperature # => 24
#
#   # Modifications have been made to the .preferences hash
#   s.preferences #=> {'color' => 'blue', 'temperature' => 24}
#
#   # Save the changes. All handled by activerecord
#   s.save!

require 'spree/core/preferences/json_coder'
require 'spree/core/preferences/preferable_class_methods'

module Spree::Preferences::Preferable
  extend ActiveSupport::Concern

  included do
    serialize :preferences, coder: Spree::Preferences::JsonCoder if defined?(serialize)
    extend Spree::Preferences::PreferableClassMethods
  end

  def get_preference(name)
    has_preference! name
    send self.class.preference_getter_method(name)
  end

  def set_preference(name, value)
    has_preference! name
    send self.class.preference_setter_method(name), value
  end

  def preference_type(name)
    has_preference! name
    send self.class.preference_type_getter_method(name)
  end

  def preference_default(name)
    has_preference! name
    send self.class.preference_default_getter_method(name)
  end

  def preference_deprecated(name)
    has_preference! name
    send(self.class.preference_deprecated_getter_method(name))
  end

  # Whether this preference is written by Spree rather than supplied by the
  # operator — a webhook secret a provider issues, say. Kept out of the
  # schema, so nothing offers it as a field to fill in.
  def preference_internal(name)
    has_preference! name
    getter = self.class.preference_internal_getter_method(name)
    # A preference declared before this option existed has no such reader.
    # Treated as not internal rather than raising, so one old declaration
    # cannot take a whole class's preference schema down with it.
    return false unless respond_to?(getter)

    send(getter)
  end

  # The fixed set this preference's value must come from, when it has one.
  # Carried into the schema so an admin form renders a picker rather than a
  # text box the operator can only get wrong.
  #
  # @return [Array, nil]
  def preference_choices(name)
    has_preference! name
    getter = self.class.preference_choices_getter_method(name)
    # A preference declared before this option existed has no such reader.
    # Treated as unconstrained rather than raising, so one old declaration
    # cannot take a whole class's preference schema down with it.
    return unless respond_to?(getter)

    send(getter)
  end

  def has_preference!(name)
    raise NoMethodError, "#{name} preference not defined" unless has_preference? name
  end

  def has_preference?(name)
    respond_to? self.class.preference_getter_method(name)
  end

  def defined_preferences
    # Only real `preference`-macro definitions carry a `_default` getter —
    # the name grep alone would also catch `preferred_*` association writers
    # (e.g. Order#preferred_stock_location=).
    methods.grep(/\Apreferred_.*=\Z/).filter_map do |pref_method|
      name = pref_method.to_s.gsub(/\Apreferred_|=\Z/, '').to_sym
      name if respond_to?(self.class.preference_default_getter_method(name))
    end
  end

  def deprecated_preferences
    defined_preferences.each_with_object([]) do |pref_name, array|
      deprecated_message = preference_deprecated(pref_name)
      array << { name: pref_name, message: deprecated_message } unless deprecated_message.nil?
    end
  end

  def default_preferences
    Hash[
      defined_preferences.map do |preference|
        [preference, preference_default(preference)]
      end
    ]
  end

  def preferences_of_type(type)
    defined_preferences.find_all { |preference| preference_type(preference) == type.to_sym }
  end

  def clear_preferences
    preferences.keys.each { |pref| preferences.delete pref }
    secret_preferences&.clear if stores_secret_preferences?
  end

  def restore_preferences_for(preference_keys)
    preference_keys.each { |pref| preference_storage(pref)[pref] = preference_default(pref) }
  end

  # Whether this record keeps `:password` preferences apart, in its encrypted
  # `secret_preferences` column (see {Spree::SecretPreferences}).
  #
  # @return [Boolean]
  def stores_secret_preferences?
    self.class.stores_secret_preferences?
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
  # saved never reads as missing. Secrets are left out: their defaults are read
  # through the `preferred_*` reader, never copied into storage.
  def backfill_default_preferences
    secrets = self.class.secret_preference_names
    missing = default_preferences.reject { |name, _| preferences.key?(name) || secrets.include?(name) }
    self.preferences = preferences.merge(missing) if missing.any?
  end

  # Names of the preferences the last save changed, across both the plain and
  # the secret column.
  #
  # @return [Array<Symbol>]
  def previously_changed_preference_names
    %w[preferences secret_preferences].flat_map do |column|
      before, after = previous_changes[column]
      next [] if before.nil? && after.nil?

      before = before || {}
      after = after || {}
      (before.keys | after.keys).reject { |key| before[key] == after[key] }
    end.map(&:to_sym).uniq
  end

  def preference_change(name, changes_or_previous_changes)
    column = preference_column(name)
    preference_changes = changes_or_previous_changes.with_indifferent_access.fetch(column, [{}, {}])
    before_preferences = preference_changes[0] || {}
    after_preferences = preference_changes[1] || {}

    return if before_preferences[name] == after_preferences[name]

    [before_preferences[name], after_preferences[name]]
  end

  private

  def preference_column(name)
    secret_preference?(name) ? 'secret_preferences' : 'preferences'
  end

  def secret_preference?(name)
    stores_secret_preferences? && self.class.secret_preference_names.include?(name.to_sym)
  end

  # The hash a preference is written to.
  def preference_storage(name)
    if secret_preference?(name)
      self.secret_preferences ||= {}
    else
      self.preferences ||= {}
    end
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
