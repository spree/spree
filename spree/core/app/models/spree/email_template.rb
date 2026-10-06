module Spree
  # A store's published version of an editable email template (an email, the
  # layout or a shared partial). Found before the template file whenever a
  # customer email renders, so it is what customers receive. Reverting marks it
  # reverted rather than deleting it, so its revisions stay reachable.
  class EmailTemplate < Spree.base_class
    has_prefix_id :etpl

    include Spree::EmailTemplateIdentity
    include Spree::HasStatus
    include Spree::ActedBy

    has_status :published, :reverted, default: :published

    publishes_events :published, :reverted

    acted_by :published_by
    acted_by :reverted_by

    has_many :revisions, -> { order(created_at: :desc) }, class_name: 'Spree::EmailTemplateRevision',
                                                           dependent: :destroy, inverse_of: :email_template

    validates :published_at, presence: true
  end
end
