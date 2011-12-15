# class_attributes are inheritied unless you reassign them in
# the subclass, so when you inherit a Preferable class, the
# inherited hook will assign a new hash for the subclass definitions
# and copy all the definitions allowing the subclass to add
# additional defintions without affecting the base
module Spree::Preferences::Preferable

  def self.included(base)
    base.class_eval do
      extend Spree::Preferences::PreferableClassMethods
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
    [self.class.name, name, (try(:id) || :new)].join('::').underscore
  end

  private

  def preference_store
    Spree::Preferences::Store.instance
  end

end

