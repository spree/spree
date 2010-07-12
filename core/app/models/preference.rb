# Represents a preferred value for a particular preference on a model.
# 
# == Targeted preferences
# 
# In addition to simple named preferences, preferences can also be targeted for
# a particular record.  For example, a User may have a preferred color for a
# particular Car.  In this case, the +owner+ is the User, the +preference+ is
# the color, and the +target+ is the Car.  This allows preferences to have a sort
# of context around them.
class Preference < ActiveRecord::Base
  belongs_to  :owner, :polymorphic => true
  belongs_to  :group, :polymorphic => true
  
  validates :name, :owner_id, :owner_type, :presence => true
  validates :group_type, :presence => true, :if => :group_id?
  
  class << self
    # Splits the given group into its corresponding id and type
    def split_group(group = nil)
      if group.is_a?(ActiveRecord::Base)
        group_id, group_type = group.id, group.class.base_class.name.to_s
      else
        group_id, group_type = nil, group
      end
      return group_id, group_type
    end
  end
  
  # The definition for the attribute
  def definition
    owner.preference_definitions[name] unless owner_type.blank?
  end
  
  # Typecasts the value depending on the preference definition's declared type
  def value
    value = read_attribute(:value)
    value = definition.type_cast(value) if definition
    value
  end
  
  # Only searches for the group record if the group id is specified
  def group_with_optional_lookup
    group_id ? group_without_optional_lookup : group_type
  end
  alias_method_chain :group, :optional_lookup
end


# Most of this code is taken from the preferences plugin available
# at http://github.com/pluginaweek/preferences/tree/master

