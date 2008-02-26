class Category < ActiveRecord::Base
  has_many :products
  acts_as_list :scope => :parent_id
  acts_as_tree :order => :position
  has_and_belongs_to_many :tax_treatments
  has_many :variations, :as => :variable, :dependent => :destroy
  validates_presence_of :name
  
  def ancestors_name
    if parent
      parent.ancestors_name + parent.name + ':'
    else
      ""
    end
  end

  def long_name
    ancestors_name + name
  end
  
  def before_save
    self.parent = nil if parent == self
  end
  
  # Serious Ruby hacking going on here.  We alias the original method for the association as added by 
  # ActiveRecord and then override it so we can return the parent category's variations if they are present.
  alias :ar_variations :variations
  def variations
    v = ar_variations
    return v unless v.empty?
    if self.parent and not self.parent.variations.empty?
      # return a frozen copy of the parent category's variations
      return Array.new(self.parent.variations).freeze   
    else
      # return category variations
      return v
    end
  end   

  # Serious Ruby hacking going on here.  We alias the original method for the association as added by 
  # ActiveRecord and then override it so we can return the parent category's treatments if they are present.
  alias :ar_tax_treatments :tax_treatments
  def tax_treatments
    tt = ar_tax_treatments
    return tt unless tt.empty?
    if self.parent and not self.parent.tax_treatments.empty?
      # return a frozen copy of the parent category's treatments
      return Array.new(self.parent.tax_treatments).freeze   
    else
      # return category tax treatments
      return tt
    end
  end   
  
  # category may have a new parent so we should be sure to remove any db records associated with 
  # the previous parent-child relationship 
  def before_update
    return if self.parent.nil?
    return if self.variations.frozen? and self.tax_treatments.frozen? # variations and treatments were inherited from previous parent - leave them alone
    unless self.parent.variations.empty? # new parent has no variations to inherit - leave the current ones alone
      self.ar_variations.each do |v|
        v.destroy
      end
    end
  end
end