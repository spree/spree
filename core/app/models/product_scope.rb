# *ProductScope* is model for storing named scopes with their arguments,
# to be used with ProductGroups.
#
# Each product Scope can be applied to Product (or product scope) with #apply_on method
# which returns new combined named scope
#
class ProductScope < ActiveRecord::Base
  # name
  # arguments
  belongs_to :product_group
  serialize :arguments

  validate :check_validity_of_scope

  extend ::Scopes::Dynamic

  # Get all products with this scope
  def products
    if Product.condition?(self.name)
      Product.send(self.name, *self.arguments)
    end
  end

  # Applies product scope on Product model or another named scope
  def apply_on(another_scope)
    another_scope.send(self.name, *self.arguments)
  end

  before_validation(:on => :create) {
    # Add default empty arguments so scope validates and errors aren't caused when previewing it
     if name && args = Scopes::Product.arguments_for_scope_name(name)
      self.arguments ||= ['']*args.length
    end
  }
  
  # checks validity of the named scope (if its safe and can be applied on Product)
  def check_validity_of_scope
    errors.add(:name, "is not a valid scope name") unless Product.condition?(self.name)
    apply_on(Product).limit(0) != nil
  rescue Exception
    errors.add(:arguments, "are incorrect")
  end

  # test ordering scope by looking for name pattern or missed arguments
  def is_ordering?
    name =~ /^(ascend_by|descend_by)/ || arguments.blank?
  end

  def to_sentence
    result = I18n.t(:sentence, :scope => [:product_scopes, :scopes, self.name], :default => "")
    result = I18n.t(:name, :scope => [:product_scopes, :scopes, self.name]) if result.blank?
    result % [*self.arguments]
  end

  def to_s
    to_sentence
  end
end
