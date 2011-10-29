class Spree::Taxonomy < ActiveRecord::Base
  validates :name, :presence => true

  has_many :taxons, :dependent => :destroy
  has_one :root, :conditions => { :parent_id => nil }, :class_name => 'Spree::Taxon'

  after_save :set_name

  private
    def set_name
      if self.root
        self.root.update_attribute(:name, self.name)
      else
        self.root = Spree::Taxon.create!({ :taxonomy_id => self.id, :name => self.name })
      end
    end
end
