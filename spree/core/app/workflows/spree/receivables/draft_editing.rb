module Spree
  module Receivables
    # Edits a draft purchase order or transfer. Past `draft` the document is a
    # matter of record, so the edit is refused rather than quietly rewriting
    # something a supplier or warehouse is already acting on. The including
    # workflow names the document (`receivable`) and the line columns callers
    # may set (`item_attributes`).
    module DraftEditing
      private

      def edit
        step :ensure_editable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :apply_changes
          step :save_document
        end

        run_hooks :after_update
        success(receivable.reload)
      end

      def ensure_editable
        return if receivable.editable?

        failure(receivable, I18n.t("spree.#{receivable.event_prefix}.errors.not_editable"))
      end

      # A whole-list replacement rather than a per-line diff: a draft's lines
      # are what the merchant is still deciding, and sending the list they
      # want is simpler for a client than working out which rows to delete.
      def apply_changes
        receivable.assign_attributes(attributes) if attributes.present?
        return if items.nil?

        receivable.items.destroy_all
        Array(items).each do |item|
          receivable.items.build(variant: item[:variant], **item_attributes.index_with { |key| item[key] })
        end
      end

      def save_document
        failure(receivable) unless receivable.save
      end
    end
  end
end
