module Spree
  # One published version of a store's email template, kept so it can be
  # restored. Append-only.
  class EmailTemplateRevision < Spree.base_class
    has_prefix_id :etrv

    include Spree::ActedBy

    belongs_to :email_template, class_name: 'Spree::EmailTemplate', inverse_of: :revisions

    acted_by :published_by

    validates :body, presence: true

    delegate :store, :key, :locale, to: :email_template
  end
end
