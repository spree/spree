module Spree
  module AgentTools
    # Which files on a record an agent may read, reached as
    # {Spree.agent_attachments}. An extension adds its own the same way it
    # registers a tool:
    #
    #   Spree.agent_attachments.register(
    #     resource: 'supplier_contracts', attachment: :document, label: 'Contract'
    #   )
    #
    # An allowlist, not a sweep of every `has_one_attached`: a subject access
    # export is one customer's entire personal data, and a digital asset is
    # the product someone paid for. Neither belongs in a model's context
    # window, and a model that grows an attachment later stays withheld until
    # somebody decides otherwise — so nothing is readable until registered.
    #
    # Permission, tenancy and record-level filtering are not repeated here:
    # the resource's {ResourceMap} entry already carries them, derived from
    # the controller that serves it. A file costs what its record costs.
    class AttachmentRegistry
      include Enumerable

      Entry = Struct.new(:resource, :attachment, :label, keyword_init: true) do
        # The map entry owning this resource's permission and scoping.
        #
        # @return [ResourceMap::Entry, nil]
        def resource_entry
          ResourceMap.find(resource)
        end

        # Records of this kind carrying this file that the caller may read.
        #
        # @param context [Spree::AgentTools::Context]
        # @return [ActiveRecord::Relation, Array]
        def scope_for(context)
          return [] unless readable_by?(context)

          resource_entry.scope_for(context).joins(:"#{attachment}_attachment")
        end

        # @param context [Spree::AgentTools::Context]
        # @return [Boolean]
        def readable_by?(context)
          entry = resource_entry
          entry.present? && context.permitted?(entry.permission)
        end

        # @param record [ActiveRecord::Base]
        # @return [ActiveStorage::Attached::One, nil]
        def attached(record)
          file = record.public_send(attachment)
          file if file.respond_to?(:attached?) && file.attached?
        end
      end

      def initialize
        @entries = {}
      end

      def each(&block)
        @entries.values.each(&block)
      end

      # @param resource [String, Symbol] the ResourceMap key owning the file
      # @param attachment [Symbol] the ActiveStorage attachment name
      # @param label [String] what a merchant calls it
      # @return [Entry]
      def register(resource:, attachment:, label:)
        @entries[resource.to_s] = Entry.new(resource: resource.to_s,
                                            attachment: attachment.to_sym,
                                            label: label)
      end

      # @param resource [String, Symbol]
      # @return [Entry, nil]
      def find(resource)
        @entries[resource.to_s]
      end

      # @return [void]
      def reset!
        @entries = {}
      end
    end
  end
end
