module Spree
  class Integration < Spree.base_class
    has_prefix_id :int

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

    # This attribute is used to temporarily store connection-related error messages
    # that can be displayed to users when testing or validating integration connections.
    # It is not persisted to the database and is reset on each new connection attempt.
    # @param message [String, nil] The error message to be stored
    # @return [String, nil] The current error message
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

    # Checks if the integration can establish a connection.
    # This is a base implementation that always returns true.
    # Subclasses should override this method to implement their own connection validation logic.
    # @return [Boolean] true if the integration can connect, false otherwise
    def can_connect?
      true
    end
  end
end
