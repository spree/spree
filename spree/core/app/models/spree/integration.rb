module Spree
  class Integration < Spree.base_class
    has_prefix_id :int

    include Spree::SingleStoreResource
    include Spree::PreferenceSchema

    registers_subclasses_via { registered_classes }

    # Integration classes registered via +Spree.integrations+. Entries may be
    # class-name strings (the documented extension form) or classes.
    #
    # @return [Array<Class>]
    def self.registered_classes
      Spree.integrations.map { |entry| entry.is_a?(Class) ? entry : entry.to_s.constantize }
    end

    #
    # Associations
    #
    belongs_to :store, class_name: 'Spree::Store', touch: true

    #
    # Validations
    #
    validates :type, presence: true
    validates :store, presence: true, uniqueness: { scope: :type }
    # An unregistered type can't be configured or displayed — reject it at
    # save rather than surfacing as a broken card in the dashboard. On change
    # only, so rows survive their gem being uninstalled.
    validate :type_must_be_registered, if: :type_changed?
    # Verify-before-activate (decisions.md 2026-08-06): saving credentials
    # never makes a network call; flipping active on does, and a failed
    # connection blocks going live with the vendor's message attached.
    validate :must_connect_when_activating, if: -> { active? && will_save_change_to_active? }

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

    # Wire shorthand for the admin API. Provider gems follow the
    # `SpreeEasyPost::Integration` convention, where demodulizing collapses
    # every gem to 'integration' — so classes named exactly `Integration`
    # derive the shorthand from their outer module instead
    # (`SpreeEasyPost` → 'easy_post').
    def self.api_type
      return super unless name.demodulize == 'Integration'

      outer = name.deconstantize.delete_prefix('Spree')
      return super if outer.blank?

      outer.underscore
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

    private

    def type_must_be_registered
      return if type.blank?
      # An empty registry means no integration gem is installed — nothing to
      # validate against (and the admin API resolves types through the
      # registry anyway, so nothing unregistered arrives from there).
      return if Spree.integrations.empty?
      return if Spree.integrations.map(&:to_s).include?(type)

      errors.add(:type, Spree.t('errors.messages.integration_type_not_registered'))
    end

    def must_connect_when_activating
      return if can_connect?

      errors.add(:active, connection_error_message.presence || Spree.t('errors.messages.integration_connection_failed'))
    end
  end
end
