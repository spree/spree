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

    attr_accessor :connection_error_message

    # Associates the integration to a group.
    # The name here will be used as Spree.t key to display the group name.
    # Leave blank to leave the integration ungrouped.
    def self.integration_group
      nil
    end

    def self.icon_path
      nil
    end

    def self.integration_name
      name.demodulize.titleize.strip
    end

    def self.integration_key
      name.demodulize.underscore
    end

    def name
      self.class.integration_name
    end

    def key
      self.class.integration_key
    end

    def can_connect?
      true
    end
  end
end
