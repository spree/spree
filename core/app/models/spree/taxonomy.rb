module Spree
  class Taxonomy < ActiveRecord::Base
    validates :name, presence: true

    has_many :taxons, inverse_of: :taxonomy
    has_one :root, -> { where parent_id: nil }, class_name: "Spree::Taxon", dependent: :destroy

    after_save :set_name

    default_scope -> { order("#{self.table_name}.position") }

    private
      def set_name
        if root
          root.update_columns(
            name: name,
            updated_at: Time.now,
          )
        else
          self.root = Taxon.create!(taxonomy_id: id, name: name)
        end
      end

  end
end
