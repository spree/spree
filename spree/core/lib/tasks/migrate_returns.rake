# Defined here rather than in lib/spree/core/ — this is a one-release upgrade
# step that dies with the legacy tables in 6.1, not engine infrastructure.
# Same placement as Spree::TypedAdjustmentsMigration in the sibling task.
module Spree
  # Copies the legacy ReturnAuthorization chain onto the 6.0 Return and
  # Exchange models. Driven by `rake spree:upgrade:migrate_returns`.
  #
  # Reads the legacy tables through throwaway model classes rather than the
  # legacy models, which no longer exist in 6.0. Historical rows are written
  # with `save(validate: false)`: they can reference deleted variants and
  # stock locations that today's validations reject, and refusing to copy
  # history is worse than copying it imperfectly.
  #
  # Resumable by construction. The legacy `number` is copied onto the new
  # record and uniquely indexed there, so the work still outstanding is a
  # query — `where.not(number: already_migrated)` — rather than tracked
  # state. An interrupted run picks up exactly where it stopped, a re-run is
  # a no-op, and there is no cursor or checkpoint that can drift out of sync
  # with what was actually written.
  class ReturnsMigrator
    LEGACY_TABLE = 'spree_return_authorizations'.freeze

    def initialize(batch_size: 500)
      @batch_size = batch_size
      @returns = 0
      @exchanges = 0
      @skipped = 0
      @failed = []
      # Schema facts, fixed for the life of the run. The column outlives the
      # table by a release: Spree::Refund stopped declaring the association
      # in 6.0 and the column drops in 6.1.
      @relink_refunds = connection.table_exists?('spree_reimbursements') &&
                        connection.column_exists?(Spree::Refund.table_name, :reimbursement_id)
    end

    # @return [Hash, nil] counts, or nil when there is nothing to migrate
    def call
      return nil unless connection.table_exists?(LEGACY_TABLE)

      pending.find_each(batch_size: batch_size) do |authorization|
        migrate_one(authorization)
      end

      { returns: @returns, exchanges: @exchanges, skipped: @skipped, failed: @failed }
    end

    private

    attr_reader :batch_size

    def connection
      ActiveRecord::Base.connection
    end

    # Authorizations not yet carried across.
    #
    # Two subqueries rather than a plucked IN-list: on a resumed run over a
    # large store the list would be every number already migrated, shipped
    # back as bind params. Both sides hit the unique index on `number`. Same
    # shape as migrate_users_to_customers' `where.not(id: model.select(:id))`.
    #
    # The NULL branch is load-bearing: `NULL NOT IN (...)` is UNKNOWN, not
    # true, so a numberless legacy row would be filtered out by the two
    # subqueries and never migrate at all. Those rows can't be matched by
    # number, so `migrated_numberless_ids` tracks them by legacy id instead —
    # otherwise a second run would copy them again under a fresh number.
    def pending
      scope = legacy_authorization.
              where.not(number: Spree::Return.select(:number)).
              where.not(number: Spree::Exchange.select(:number))

      numberless = legacy_authorization.where(number: nil).
                   where.not(id: migrated_numberless_ids)

      legacy_authorization.where(id: scope.select(:id)).or(
        legacy_authorization.where(id: numberless.select(:id))
      )
    end

    # Numberless rows are stamped with their legacy id at copy time, which is
    # the only durable link back to the source row.
    def migrated_numberless_ids
      @migrated_numberless_ids ||=
        (Spree::Return.where.not(metadata: nil).pluck(:metadata) +
         Spree::Exchange.where.not(metadata: nil).pluck(:metadata)).
        filter_map { |data| parse_metadata(data)['legacy_return_authorization_id'] }
    end

    def parse_metadata(data)
      return data if data.is_a?(Hash)

      JSON.parse(data.to_s)
    rescue JSON::ParserError
      {}
    end

    def legacy_authorization
      @legacy_authorization ||= Class.new(Spree.base_class) do
        self.table_name = LEGACY_TABLE
        def self.name = 'LegacyReturnAuthorization'
      end
    end

    def legacy_item
      @legacy_item ||= Class.new(Spree.base_class) do
        self.table_name = 'spree_return_items'
        def self.name = 'LegacyReturnItem'
      end
    end

    def migrate_one(authorization)
      items = legacy_item.where(return_authorization_id: authorization.id).to_a
      order = Spree::Order.find_by(id: authorization.order_id)

      if items.empty? || order.nil?
        @skipped += 1
        return
      end

      # One lookup for the whole authorization rather than one per item.
      fulfillment_items = Spree::FulfillmentItem.
                          where(id: items.filter_map(&:fulfillment_item_id).uniq).index_by(&:id)

      exchange = items.any? { |item| item.exchange_variant_id.present? }

      ActiveRecord::Base.transaction do
        record =
          if exchange
            build_exchange(authorization, items, order, fulfillment_items)
          else
            build_return(authorization, items, order, fulfillment_items)
          end

        relink_refunds(items, record)
      end

      # After the transaction commits, never before: a row that raises is
      # recorded in @failed only, so the counts and the failure list can't
      # both claim the same authorization.
      exchange ? @exchanges += 1 : @returns += 1
    rescue StandardError => error
      @failed << "##{authorization.id} (#{authorization.number || 'no number'}): #{error.message}"
    end

    # A legacy authorization only ever reached "authorized" or "canceled";
    # how far the return actually got is recorded on its items instead.
    #
    # `settled_as` is what a reimbursed row becomes: a Return was refunded,
    # an Exchange was fulfilled — money back on an exchange is the price
    # difference, which the legacy chain settled at reimbursement time.
    def status_for(authorization, items, settled_as: 'refunded')
      return 'canceled' if authorization.state == 'canceled'
      return settled_as if items.any? { |item| item.reimbursement_id.present? }
      return 'received' if items.any? { |item| item.reception_status == 'received' }

      'approved'
    end

    # The header both record types share: same attributes, same preserved
    # number, same unvalidated save. Only the class and the settled status
    # differ, and keeping this in one place is what stops the two save paths
    # drifting apart.
    def build_header(klass, authorization, order, status)
      record = klass.new(
        store: order.store,
        order: order,
        stock_location_id: authorization.stock_location_id,
        reason_id: authorization.return_authorization_reason_id,
        memo: authorization.memo,
        status: status,
        created_at: authorization.created_at,
        updated_at: authorization.updated_at
      )
      # Required, not an optimisation: NumberGenerator assigns the number in a
      # before_validation hook, which save!(validate: false) below skips — so
      # without this the NOT NULL constraint on `number` rejects the row. The
      # legacy number is also what makes a re-run idempotent, so a generated
      # one would break resumption as well as lose the link to history.
      #
      # A legacy row with no number can't participate in either, so it falls
      # back to a generated one and records where it came from — that stamp is
      # what `migrated_numberless_ids` reads to keep a re-run from copying it
      # a second time under a different generated number.
      if authorization.number.present?
        record.number = authorization.number
      else
        record.number = record.generate_permalink(klass)
        # write_attribute, not #metadata= — see migrated_numberless_ids.
        record.write_attribute(:metadata, { 'legacy_return_authorization_id' => authorization.id })
      end

      record.save!(validate: false)
      record
    end

    def build_return(authorization, items, order, fulfillment_items)
      record = build_header(Spree::Return, authorization, order, status_for(authorization, items))

      items.each do |item|
        fulfillment_item = fulfillment_items[item.fulfillment_item_id]

        record.return_line_items.new(
          line_attributes_for(item, fulfillment_item).merge(
            variant_id: fulfillment_item&.variant_id,
            pre_tax_amount: item.pre_tax_amount,
            resellable: item.resellable
          )
        ).save!(validate: false)
      end

      record
    end

    def build_exchange(authorization, items, order, fulfillment_items)
      record = build_header(
        Spree::Exchange, authorization, order,
        status_for(authorization, items, settled_as: 'fulfilled')
      )

      items.each do |item|
        next if item.exchange_variant_id.blank?

        fulfillment_item = fulfillment_items[item.fulfillment_item_id]

        record.exchange_line_items.new(
          line_attributes_for(item, fulfillment_item).merge(
            original_variant_id: fulfillment_item&.variant_id,
            new_variant_id: item.exchange_variant_id
          )
        ).save!(validate: false)
      end

      record
    end

    def line_attributes_for(item, fulfillment_item)
      {
        fulfillment_item_id: item.fulfillment_item_id,
        line_item_id: fulfillment_item&.line_item_id,
        quantity: 1,
        received_quantity: item.reception_status == 'received' ? 1 : 0,
        created_at: item.created_at,
        updated_at: item.updated_at
      }
    end

    # Keeps the money history attached to something the admin can still see.
    #
    # Addresses spree_refunds.reimbursement_id by column name rather than
    # through the association: Spree::Refund no longer declares it in 6.0,
    # and the column itself is dropped in 6.1.
    def relink_refunds(items, record)
      return unless @relink_refunds

      reimbursement_ids = items.filter_map(&:reimbursement_id).uniq
      return if reimbursement_ids.empty?

      Spree::Refund.where(reimbursement_id: reimbursement_ids).
        update_all(originator_type: record.class.to_s, originator_id: record.id)
    end
  end
end

namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Moves the legacy ReturnAuthorization chain onto the 6.0 returns models
      (docs/plans/6.0-returns-exchanges-claims.md).

      Each +spree_return_authorizations+ row becomes a +Spree::Return+, or a
      +Spree::Exchange+ when any of its return items named an exchange variant.
      Refunds produced through a reimbursement are re-pointed at the new record
      via the polymorphic +originator+, so the money history stays attached to
      something the admin can still see.

      Resumable by construction: the legacy +number+ is copied onto the new
      record and uniquely indexed there, so the task scopes itself to the
      authorizations whose number isn't present yet. An interrupted run picks
      up exactly where it stopped, and re-running when nothing is left is a
      no-op — no cursor to track, no state to reset.

      Reads the legacy tables by name through throwaway model classes; the
      legacy models themselves are deleted in 6.0. The tables stay in place as
      a rollback safety net and drop in 6.1.

      A row that can't be converted is reported and skipped so one bad
      authorization doesn't stop the batch, but the task then aborts, because
      an upgrade must not continue on top of incomplete returns history.
      Re-run to retry those rows, or pass SKIP_FAILED_ROWS=true to accept the
      gap and continue.

      Set BATCH_SIZE to tune how many authorizations are loaded at a time
      (default 500).
    DESC
    task migrate_returns: :environment do
      options = ENV['BATCH_SIZE'] ? { batch_size: ENV['BATCH_SIZE'].to_i } : {}
      result = Spree::ReturnsMigrator.new(**options).call

      if result.nil?
        puts '  spree_return_authorizations not found — nothing to migrate.'
        next
      end

      puts "  Migrated #{result[:returns]} return(s) and #{result[:exchanges]} exchange(s); " \
           "skipped #{result[:skipped]}."

      next if result[:failed].empty?

      # Aborts so upgrade automation stops here rather than carrying on with
      # returns history that is missing rows. Every failure is retried by
      # simply re-running — the task scopes itself to what isn't migrated yet.
      puts "  #{result[:failed].size} row(s) could not be migrated:"
      result[:failed].each { |line| puts "  #{line}" }

      if ENV['SKIP_FAILED_ROWS'] == 'true'
        puts '  Continuing anyway (SKIP_FAILED_ROWS=true).'
      else
        abort '  Re-run to retry them, or pass SKIP_FAILED_ROWS=true to accept the gap and continue.'
      end
    end
  end
end
