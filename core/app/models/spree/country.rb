module Spree
  class Country < Spree::Base
    has_many :states, -> { order('name ASC') }, dependent: :destroy
    has_many :addresses, dependent: :nullify

    has_many :zone_members, as: :zoneable, dependent: :destroy

    validates :name, :iso_name, presence: true

    def <=>(other)
      name <=> other.name
    end

    def to_s
      name
    end
  end
end
