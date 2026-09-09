module Spree
  # Paperwork a carrier produced beside the label — a commercial invoice, a
  # customs declaration — returned by a fulfillment provider's +documents+.
  #
  # Ephemeral, never persisted: the file stays hosted by the carrier and the
  # provider re-derives this on read. It is a typed object rather than a hash
  # so the contract has one definition, and so promoting it to a record later
  # (with a stored file, the way +Spree::ShippingLabel+ keeps its own) is a
  # change to this class rather than to every provider and serializer.
  #
  # +kind+ is the carrier's own word for the document and is deliberately not
  # validated against a list: which papers a shipment needs is the carrier's
  # and the border's business, not Spree's vocabulary to fix, and an unknown
  # kind renders humanised rather than being dropped.
  class ShippingDocument
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :kind, :string, default: 'form'
    attribute :url, :string

    validates :url, presence: true

    # Serializers render documents as plain objects; keeping the shape here
    # means the API contract does not depend on how a provider spells it.
    #
    # @return [Hash]
    def as_json(*)
      { kind: kind, url: url }
    end
  end
end
