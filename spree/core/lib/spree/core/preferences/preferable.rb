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

  BOOLEAN_TYPE = ActiveModel::Type::Boolean.new

  included do
    serialize :preferences, coder: Spree::Metadata::HashSerializer
    extend Spree::Preferences::PreferableClassMethods

    # The preferences read and written under their plain names (see `exposes_preferences`).
    class_attribute :exposed_preference_names, instance_accessor: false, default: Set.new.freeze
  end

  # JSON keeps decimals and times as strings; the declared type turns them
  # back into a BigDecimal and a time. Anything else, or a string that does
  # not parse, comes back as stored.
  #
  # @param value [Object] a value as JSON stores it
  # @param type [Symbol] the preference's declared type
  # @return [Object]
  def self.restore_value(value, type)
    return value unless value.is_a?(String)

    case type
    when :decimal, :money then BigDecimal(value, exception: false) || value
    when :datetime then Time.zone.iso8601(value)
    else value
    end
  rescue ArgumentError
    value
  end

  # The record class an `of: :id` preference points at. Declared as a class
  # name or a block, so a declaration never loads another model, nor fixes a
  # configurable class like `Spree.customer_class`, at class load.
  #
  # @param definition [Hash] a preference definition
  # @return [Class]
  def self.preference_model(definition)
    model = definition[:model]
    model.respond_to?(:call) ? model.call : model.to_s.constantize
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
  # before secrets moved to their own column. Declared preferences read
  # through their `preferred_*` reader, so a default applies and decimals and
  # times come back typed rather than in the string form JSON stores.
  #
  # @return [ActiveSupport::HashWithIndifferentAccess]
  def preference_values
    (preferences || {}).to_h.with_indifferent_access.merge(defined_preferences.index_with { |name| get_preference(name) })
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
  #
  # Filling in a default is not a change to a stored record: a loaded record
  # stays clean, so `with_lock` still accepts it, and the defaults are written
  # with its next real save.
  def backfill_default_preferences
    secrets = self.class.secret_preference_names
    missing = defined_preferences.reject { |name| preferences.key?(name) || secrets.include?(name) }
    return if missing.empty?

    already_changed = attribute_changed?(:preferences)
    self.preferences = preferences.merge(missing.index_with { |name| stored_default(name) })
    clear_attribute_change(:preferences) if persisted? && !already_changed
  end

  # Writes a `preferences` payload an API client sent. The whole payload is
  # checked against the type's schema first, so nothing is written when any
  # value is wrong. Then each value goes through its typed writer. A secret
  # sent back masked, as it was read, keeps the stored one; `null` clears it.
  #
  # @param values [Hash, ActionController::Parameters]
  # @param pointer [String] where the preferences object sits in the request,
  #   e.g. `/rules/1/preferences`, so a failure names its place
  # @raise [Spree::Preferences::InvalidPreferences] naming every value that does not match
  # @return [void]
  def assign_preferences(values, pointer: '/preferences')
    values = values.respond_to?(:to_unsafe_h) ? values.to_unsafe_h : values.to_h
    values = values.deep_stringify_keys
    failures = self.class.preference_failures(values)
    raise Spree::Preferences::InvalidPreferences.new(failures, prefix: pointer) if failures.any?

    values.each do |key, value|
      next if secret_preference?(key) && Spree::Preferences::Masking.masked?(value)

      begin
        set_preference(key, value)
      rescue ActiveRecord::RecordNotFound => e
        raise Spree::Preferences::InvalidPreferences.new([{ pointer: "/#{key}", message: e.message }], prefix: pointer)
      end
    end
  end

  # A stored value in the form the schema describes. Rows written before the
  # declarations were typed can hold a number where an exact decimal string
  # is declared (an `amounts` hash, a decimal default from YAML), or a string
  # where a number or boolean is; read back as they are, a client sending
  # them unchanged would be refused.
  #
  # @param value [Object] the stored value
  # @param definition [Hash] its preference definition
  # @return [Object]
  def wire_preference_value(value, definition)
    return BigDecimal(value.to_s).as_json if definition[:type] == :decimal && value.is_a?(Numeric)
    if %i[integer boolean].include?(definition[:type]) && value.is_a?(String)
      return convert_preference_value(value, definition[:type], nullable: definition[:nullable])
    end
    return value if value.nil? || (definition[:type] == :array && !value.is_a?(Array))

    cast_preference_contents(value, definition)
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

  # A declared default in the form JSON stores, as the writer would store it,
  # so a decimal default reads back as a BigDecimal and setting the same
  # amount is not a change.
  def stored_default(name)
    default = preference_default(name)
    type = preference_type(name)
    return default if default.nil? || %i[decimal money datetime].exclude?(type)

    convert_preference_value(default, type, nullable: true).as_json
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
    # Spree 6.0 bridge, removed with incomplete declarations in 6.1: an id list
    # an extension declared without `of: :id` still has its prefixed ids
    # decoded, as the API did for every `*_ids` key before.
    if definition[:type] == :array && definition[:of].nil? && name.to_s.end_with?('_ids') && value.is_a?(Array)
      value = value.map { |id| (Spree::PrefixedId.decode_prefixed_id(id) if Spree::PrefixedId.prefixed_id?(id)) || id }
    end
    value = convert_preference_value(value, definition[:type], nullable: definition[:nullable])
    value = cast_preference_contents(value, definition)
    # Decimals and times are kept in the string form JSON stores, so a record
    # read back from the database and one just written compare equal and
    # setting the same value is not a change. The reader restores them.
    value = value.as_json if %i[decimal money datetime].include?(definition[:type])

    Spree::Deprecation.warn("`#{name}` is deprecated. #{definition[:deprecated]}") if definition[:deprecated]
    value
  end

  # Casts what a typed `:array` or `:hash` holds to its declared item type, in
  # the form JSON stores. A value that does not cast is left as it came, so
  # validation can name it rather than a silent zero hiding it.
  def cast_preference_contents(value, definition)
    case definition[:type]
    when :array
      case definition[:of]
      when nil then value
      when :id then decode_preference_ids(value, definition)
      when :object then value.map { |item| cast_preference_object(item, definition[:properties]) }
      else split_preference_list(value).map { |item| cast_preference_item(item, definition[:of]) }
      end
    when :hash
      return value unless definition[:values] && value.is_a?(Hash)

      value.to_h do |key, item|
        key = definition[:keys] == :currency ? key.to_s.upcase : key.to_s
        [key, cast_preference_item(item, definition[:values])]
      end
    else
      value
    end
  end

  # A comma-separated string is a list too: what a plain text field sends.
  def split_preference_list(values)
    values.flat_map { |item| item.is_a?(String) ? item.split(',') : [item] }
          .map { |item| item.is_a?(String) ? item.strip : item }
          .reject { |item| item.respond_to?(:empty?) && item.empty? }
  end

  def cast_preference_item(value, item_type)
    case item_type
    when :string then value.to_s
    when :integer then Integer(value.to_s, 10, exception: false) || value
    when :decimal, :money then BigDecimal(value.to_s, exception: false)&.as_json || value
    when :boolean then BOOLEAN_TYPE.cast(value)
    else value
    end
  end

  def cast_preference_object(item, properties)
    return item unless item.respond_to?(:to_h) && !item.is_a?(Array)

    item.to_h.stringify_keys.slice(*properties.keys.map(&:to_s)).to_h do |key, value|
      [key, cast_preference_item(value, properties[key.to_sym])]
    end
  end

  # Turns a list of record ids into the raw primary keys the preference
  # stores. A prefixed id must carry the declared model's prefix — a
  # channel's id never decodes into a market id — and every id must belong to
  # the record's scope, so a rule cannot point at another store's records.
  #
  # @raise [ActiveRecord::RecordNotFound] naming the ids that were not found
  def decode_preference_ids(values, definition)
    model = Spree::Preferences::Preferable.preference_model(definition)
    ids = split_preference_list(values).map(&:to_s).map do |id|
      Spree::PrefixedId.prefixed_id?(id) ? (model.decode_prefixed_id(id)&.to_s || id) : id
    end
    return ids if ids.empty?

    relation = definition[:scope] ? definition[:scope].call(self) : model
    found = relation.where(id: ids.reject { |id| Spree::PrefixedId.prefixed_id?(id) }).pluck(:id).map(&:to_s).to_set
    missing = ids.reject { |id| found.include?(id) }
    if missing.any?
      raise ActiveRecord::RecordNotFound.new("Couldn't find #{model.name} with id=#{missing.join(',')}", model.name)
    end

    ids
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
    when :decimal, :money
      # A number or canonical decimal text only: "1,599.99" raises rather
      # than being read as 1.
      decimal_value = value.is_a?(String) ? value.presence : value
      decimal_value ||= 0 unless nullable
      decimal_value.nil? ? nil : Spree::Money::Rounding.parse_decimal(decimal_value)
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
