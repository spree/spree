# The preference_cache_key is used to determine if the preference
# can be set. The default behavior is to return nil if there is no
# id value. On ActiveRecords, new objects will have their preferences
# saved to a pending hash until it is persisted.
#
# class_attributes are inheritied unless you reassign them in
# the subclass, so when you inherit a Preferable class, the
# inherited hook will assign a new hash for the subclass definitions
# and copy all the definitions allowing the subclass to add
# additional defintions without affecting the base
module Spree::Preferences::Preferable

  def self.included(base)
    base.class_eval do
      extend Spree::Preferences::PreferableClassMethods

      if respond_to?(:after_create)
        after_create do |obj|
          obj.save_pending_preferences
        end
      end

      if respond_to?(:after_destroy)
        after_destroy do |obj|
          obj.clear_preferences
        end
      end

    end
  end

  def get_preference(name)
    has_preference! name
    send self.class.preference_getter_method(name)
  end
  alias :preferred :get_preference
  alias :prefers? :get_preference

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

  def preference_description(name)
    has_preference! name
    send self.class.preference_description_getter_method(name)
  end

  def has_preference!(name)
    raise NoMethodError.new "#{name} preference not defined" unless has_preference? name
  end

  def has_preference?(name)
    respond_to? self.class.preference_getter_method(name)
  end

  def preferences
    prefs = {}
    methods.grep(/^prefers_.*\?$/).each do |pref_method|
      prefs[pref_method.to_s.gsub(/prefers_|\?/, '').to_sym] = send(pref_method)
    end
    prefs
  end

  def prefers?(name)
    get_preference(name)
  end

  def preference_cache_key(name)
    return unless id
    [self.class.name, name, id].join('::').underscore
  end

  def save_pending_preferences
    return unless @pending_preferences
    @pending_preferences.each do |name, value|
      set_preference(name, value)
    end
  end

  def clear_preferences
    preferences.keys.each {|pref| preference_store.delete preference_cache_key(pref)}
  end

  private

  def add_pending_preference(name, value)
    @pending_preferences ||= {}
    @pending_preferences[name] = value
  end

  def get_pending_preference(name)
    return unless @pending_preferences
    @pending_preferences[name]
  end

  def convert_preference_value(value, type)
    case type
    when :string, :text
      value.to_s
    when :password
      value.to_s
    when :decimal
      BigDecimal.new(value.to_s).round(2, BigDecimal::ROUND_HALF_UP)
    when :integer
      value.to_i
    when :boolean
      if value.is_a?(FalseClass) ||
         value.nil? ||
         value == 0 ||
         value =~ /^(f|false|0)$/i ||
         (value.respond_to? :empty? and value.empty?)
         false
      else
         true
      end
    else
      value
    end
  end

  def preference_store
    Spree::Preferences::Store.instance
  end

end

