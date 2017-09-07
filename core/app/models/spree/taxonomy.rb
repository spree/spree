module Spree
  class Taxonomy < Spree::Base
    acts_as_list

    validates :name, presence: true, uniqueness: { case_sensitive: false, allow_blank: true }

    has_many :taxons, inverse_of: :taxonomy
    has_one :root, -> { where parent_id: nil }, class_name: 'Spree::Taxon', dependent: :destroy

    after_create :set_root
    after_save :set_root_taxon_name

    default_scope { order("#{table_name}.position, #{table_name}.created_at") }

    private

    def set_root
      self.root ||= Taxon.create!(taxonomy_id: id, name: name)
    end

    def set_root_taxon_name
      root.update_attributes(name: name)
    end
  end
end
