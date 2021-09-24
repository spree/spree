module Spree
  class Relation < ActiveRecord::Base
    belongs_to :relation_type
    belongs_to :relatable, polymorphic: true
    belongs_to :related_to, polymorphic: true

    validates :relation_type, :relatable, :related_to, presence: true
  end
end
