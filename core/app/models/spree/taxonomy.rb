module Spree
  class Taxonomy < ActiveRecord::Base
    validates :name, :presence => true

    attr_accessible :name

    has_many :taxons
    has_one :root, :conditions => { :parent_id => nil }, :class_name => "Spree::Taxon",
                   :dependent => :destroy

    after_save :set_name

    private
      def set_name
        if root
          root.update_attribute(:name, name)
        else
          self.root = Taxon.create!({ :taxonomy_id => id, :name => name }, :without_protection => true)
        end
      end

  end
end
