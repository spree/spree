class Category < ActiveRecord::Base
  has_many :products
  acts_as_list :scope => :parent_id
  acts_as_tree :order => :position
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
end