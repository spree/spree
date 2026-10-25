module Spree
  # Work in progress on an editable email template, one per store, template
  # and language. Shared by every admin of the store: `lock_version` refuses a
  # save made from a stale copy, and `updated_by` says who saved it last.
  class EmailTemplateDraft < Spree.base_class
    has_prefix_id :etdr

    include Spree::EmailTemplateIdentity
    include Spree::ActedBy

    acted_by :updated_by
  end
end
