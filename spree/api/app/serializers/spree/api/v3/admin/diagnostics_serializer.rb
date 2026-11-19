module Spree
  module Api
    module V3
      module Admin
        # The diagnostics report (Spree::Diagnostics::Report). A computed
        # value rather than a record, so it carries no id. `errors[].error_class`
        # is an exception's class name on purpose: it is what a maintainer
        # reads in a bug report, not a value any client branches on.
        class DiagnosticsSerializer < V3::BaseSerializer
          typelize generated_at: :string,
                   spree_version: :string,
                   markdown: :string,
                   issue_url: :string,
                   issue_prefilled: :boolean,
                   sections: 'Array<{ key: string; title: string; rows: Array<{ label: string; value: string }> }>',
                   errors: 'Array<{ error_class: string; source: string | null; frames: string[]; ' \
                           'request_id: string | null; count: number; first_seen_at: string; last_seen_at: string }>'

          _attributes.delete(:id)

          attributes :spree_version, :sections, :errors, generated_at: :iso8601

          attribute(:markdown, &:to_markdown)
          attribute(:issue_url, &:issue_url)
          attribute(:issue_prefilled, &:issue_prefilled?)
        end
      end
    end
  end
end
