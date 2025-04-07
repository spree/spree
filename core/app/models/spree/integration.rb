module Spree
  class Integration < Spree.base_class
    include Spree::SingleStoreResource

    #
    # Associations
    #
    belongs_to :store, class_name: 'Spree::Store', touch: true

    #
    # Validations
    #
    validates :type, presence: true
    validates :store, presence: true, uniqueness: { scope: :type }

    #
    # Scopes
    #
    scope :active, -> { where(active: true) }

    def can_connect?
      true
    end

    def self.integration_name
      name.demodulize.titleize.strip
    end

    def self.icon_path
      nil
    end

    def name
      self.class.integration_name
    end

    def form_partial_name
      name.underscore
    end
  end
end
