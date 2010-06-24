class Taxonomy < ActiveRecord::Base
  has_many :taxons, :dependent => :destroy
  has_one :root, :class_name => 'Taxon', :conditions => "parent_id is null"

  after_save :set_name

  def set_name
    if self.root
      self.root.update_attribute(:name, self.name)
    else
      self.root = Taxon.create!({
          :taxonomy_id => self.id,
          :name => self.name
        })
    end
  end
end
