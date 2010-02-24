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

  named_scope :ordering, :conditions => ["name IN (?)", Scopes::Product::ORDERING.map(&:to_s)]
  named_scope :not_ordering, :conditions => ["name NOT IN (?)", Scopes::Product::ORDERING.map(&:to_s)]
  
  
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

  def before_validation_on_create
    # Add default empty arguments so scope validates and errors aren't caused when previewing it
    if args = Scopes::Product.arguments_for_scope_name(name)
      self.arguments ||= ['']*args.length
    end
  end
  
  # checks validity of the named scope (if it's safe and can be applied on Product)
  def validate
    errors.add(:name, "is not propper scope name") unless Product.condition?(self.name)
    apply_on(Product).inspect
  rescue Exception
    errors.add(:arguments, "arguments are incorrect")
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
