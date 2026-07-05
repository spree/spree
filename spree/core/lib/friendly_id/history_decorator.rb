module FriendlyId
  module HistoryDecorator
    private

    # This a patch to friendly_id history module.
    # Originally, it removes and re-creates a slug record if it already exists. The issue is that we use `acts_as_paranoid`
    # for slugs so it sets the `deleted_at` timestamp instead of deleting the record. We need to delete the record instead.
    def create_slug
      return unless friendly_id
      return if history_is_up_to_date?
      # Allow reversion back to a previously used slug
      relation = slugs.where(slug: friendly_id)
      if friendly_id_config.uses?(:scoped)
        relation = relation.where(scope: serialized_scope)
      end
      # Use `delete_all` instead of `destroy_all` to avoid the unique index error.
      relation.delete_all unless relation.empty?
      slugs.create! do |record|
        record.slug = friendly_id
        record.scope = serialized_scope if friendly_id_config.uses?(:scoped)
      end
    end
  end
end

FriendlyId::History.prepend(FriendlyId::HistoryDecorator)
