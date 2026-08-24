module Spree
  # Gives a model identities in external systems (ERP, PIM, DAM, CRM) through
  # {Spree::ExternalReference}. Opt-in per resource rather than on
  # {Spree::Base}: only records a connector actually syncs need the association.
  module HasExternalReferences
    extend ActiveSupport::Concern

    included do
      has_many :external_references, class_name: 'Spree::ExternalReference', as: :resource, dependent: :destroy

      # Scope-friendly so controllers can chain it onto an already store-scoped
      # relation: `current_store.products.with_external_id('erp', 'MAT-100')`.
      # Scoping the lookup to the store is the caller's job, exactly as with any
      # other id coming off a request.
      scope :with_external_id, lambda { |system, external_id|
        joins(:external_references).where(
          spree_external_references: {
            system: system.to_s.strip.downcase,
            external_id: external_id.to_s.strip
          }
        )
      }
    end

    # @param system [String, Symbol] the external system's key
    # @return [String, nil] the identifier that system knows this record by
    def external_id_for(system)
      key = system.to_s.strip.downcase

      if external_references.loaded?
        external_references.detect { |reference| reference.system == key }&.external_id
      else
        external_references.for_system(key).pick(:external_id)
      end
    end

    # Creates or updates this record's identity in one external system.
    #
    # @param system [String, Symbol] the external system's key
    # @param external_id [String, nil] blank removes the reference
    # @param metadata [Hash, nil] connector bookkeeping (version, etag, synced at)
    # @return [Spree::ExternalReference, nil] nil when the reference was removed
    def set_external_id(system, external_id, metadata: nil)
      key = system.to_s.strip.downcase
      reference = external_references.for_system(key).first

      if external_id.to_s.strip.blank?
        reference&.destroy
        external_references.reset
        return nil
      end

      reference ||= external_references.build(system: key)
      reference.external_id = external_id
      reference.metadata = metadata if metadata.present?
      reference.store ||= external_reference_store
      reference.save!
      # Reset rather than reload: the next reader refetches, and a batch of
      # writes pays for one SELECT at the end instead of one per system.
      external_references.reset
      reference
    end

    # Writes several references at once, leaving systems the payload does not
    # mention untouched — a connector states its own key without disturbing
    # another system's. Accepts the `{ system => external_id }` map the admin
    # serializers render, or a list of `{ system:, external_id: }` entries.
    #
    # @param references [Hash{String,Symbol=>String}, Array<Hash>]
    # @return [void]
    def assign_external_references(references)
      Spree::ExternalReference.normalize_references(references).each do |reference|
        set_external_id(reference[:system], reference[:external_id], metadata: reference[:metadata])
      end
    end

    private

    # A reference belongs to the same store as the record it identifies.
    #
    # Store-owning models answer directly (and CompanyLocation delegates);
    # variants and stock levels carry no store of their own and reach it
    # through the product. Anything else is left nil here — the reference
    # includes {Spree::SingleStoreResource}, whose ensure_store callback
    # falls back to the request's store, and stating that fallback twice
    # would let the two quietly diverge.
    def external_reference_store
      return store if respond_to?(:store) && store.present?

      product.store if respond_to?(:product) && product&.store.present?
    end
  end
end
