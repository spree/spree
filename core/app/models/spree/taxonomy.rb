module Spree
  class Taxonomy < ActiveRecord::Base
    validates :name, :presence => true

    attr_accessible :name

    has_many :taxons
    has_one :root, :conditions => { :parent_id => nil }, :class_name => 'Spree::Taxon'

    after_save :set_name
    after_destroy :destroy_root_taxon

    private
      def set_name
        if self.root
          self.root.update_attribute(:name, self.name)
        else
          self.root = Taxon.create!({ :taxonomy_id => self.id, :name => self.name })
        end
      end

      def destroy_root_taxon
        self.root.destroy
      end
  end
end
