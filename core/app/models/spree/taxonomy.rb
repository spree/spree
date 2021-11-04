module Spree
  class Taxonomy < Spree::Base
    include Metadata

    acts_as_list

    validates :name, presence: true, uniqueness: { case_sensitive: false, allow_blank: true, scope: :store_id }
    validates :store, presence: true

    has_many :taxons, inverse_of: :taxonomy
    has_one :root, -> { where parent_id: nil }, class_name: 'Spree::Taxon', dependent: :destroy
    belongs_to :store, class_name: 'Spree::Store'

    after_create :set_root
    after_save :set_root_taxon_name

    default_scope { order("#{table_name}.position, #{table_name}.created_at") }

    private

    def set_root
      self.root ||= Taxon.create!(taxonomy_id: id, name: name)
    end

    def set_root_taxon_name
      root.update(name: name)
    end
  end
end
