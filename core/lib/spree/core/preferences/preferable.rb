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
#   # Spree::Base includes Preferable and defines preferences as a serialized
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
#   s.preferences #=> {color: 'blue', temperature: 24}
#
#   # Save the changes. All handled by activerecord
#   s.save!

require 'spree/core/preferences/preferable_class_methods'

module Spree::Preferences::Preferable
  extend ActiveSupport::Concern

  included do
    serialize :preferences, type: Hash, coder: YAML if defined?(serialize)
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

  def has_preference!(name)
    raise NoMethodError, "#{name} preference not defined" unless has_preference? name
  end

  def has_preference?(name)
    respond_to? self.class.preference_getter_method(name)
  end

  def defined_preferences
    methods.grep(/\Apreferred_.*=\Z/).map do |pref_method|
      pref_method.to_s.gsub(/\Apreferred_|=\Z/, '').to_sym
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
  end

  def restore_preferences_for(preference_keys)
    preference_keys.each { |pref| preferences[pref] = preference_default(pref) }
  end

  def preference_change(name, changes_or_previous_changes)
    preference_changes = changes_or_previous_changes.with_indifferent_access.fetch('preferences', [{}, {}])
    before_preferences = preference_changes[0] || {}
    after_preferences = preference_changes[1] || {}

    return if before_preferences[name] == after_preferences[name]

    [before_preferences[name], after_preferences[name]]
  end

  private

  def convert_preference_value(value, type, nullable: false)
    case type
    when :string, :text
      value.to_s
    when :password
      value.to_s
    when :decimal
      decimal_value = value.presence
      decimal_value ||= 0 unless nullable
      decimal_value.present? ? decimal_value.to_s.to_d : decimal_value
    when :integer
      value.to_i
    when :boolean
      if value.is_a?(FalseClass) ||
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
    else
      value
    end
  end
end
