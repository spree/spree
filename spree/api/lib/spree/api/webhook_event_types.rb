module Spree
  module Api
    # Renders the event catalog ({Spree::Events.catalog}) into the typed event
    # map `@spree/sdk/webhooks` exports and the matching Zod schema map, so a
    # webhook consumer's `event.name` check narrows `event.data` to the record
    # the event carries.
    #
    # Run by `rake typelizer:generate`; `webhook_event_types_spec.rb` fails when
    # the committed files no longer match the catalog.
    class WebhookEventTypes
      # The payload of an event whose record has no Store serializer.
      RECORD_REFERENCE = 'WebhookRecordReference'.freeze
      BACK_OFFICE_SERIALIZER = /\ASpree::Api::V3::\w+::/
      HEADER = "// This file is auto-generated from Spree's event catalog by `rake typelizer:generate`. Do not edit directly.\n".freeze

      FILES = {
        types: 'packages/sdk/src/webhooks/generated/events.ts',
        schemas: 'packages/sdk/src/webhooks/generated/schemas.ts'
      }.freeze

      # @param catalog [Spree::Events::Catalog]
      def initialize(catalog = Spree::Events.catalog)
        @catalog = catalog
      end

      # @return [Hash{Symbol => String}] file contents keyed like {FILES}
      def render
        { types: types_source, schemas: schemas_source }
      end

      # Writes both files under the monorepo root.
      #
      # @param root [Pathname]
      # @return [void]
      def write!(root)
        render.each do |key, source|
          path = root.join(FILES.fetch(key))
          FileUtils.mkdir_p(path.dirname)
          File.write(path, source)
        end
      end

      private

      attr_reader :catalog

      def entries
        @entries ||= catalog.webhook_events
      end

      def payload_type_names
        @payload_type_names ||= type_names.values.uniq.sort - [RECORD_REFERENCE]
      end

      def type_name(entry)
        type_names.fetch(entry.name)
      end

      def type_names
        @type_names ||= entries.to_h { |entry| [entry.name, resolve_type_name(entry)] }
      end

      # Named the way the Store SDK's type writer names it. A back-office shape
      # stays behind the Admin API even when a Store-level class inherits it
      # (docs/plans/6.0-typed-webhook-events.md).
      def resolve_type_name(entry)
        serializer = entry.payload_serializer
        return RECORD_REFERENCE unless serializer

        back_office = serializer.ancestors.grep(Class).any? { |ancestor| ancestor.name.to_s.match?(BACK_OFFICE_SERIALIZER) }
        if back_office || store_writer.reject_class.call(serializer: serializer)
          raise ArgumentError, "#{entry.name} is built by #{serializer.name}, which is not a Store API serializer"
        end

        store_writer.serializer_name_mapper.call(serializer)
      end

      def store_writer
        Typelizer.configuration.writers.fetch(:store)
      end

      def types_source
        <<~TS
          #{HEADER}import type {
          #{payload_type_names.map { |name| "  #{name}," }.join("\n")}
          } from '../../types/generated'

          /** The payload of an event whose record has no Store API representation. */
          export interface #{RECORD_REFERENCE} {
            id: string
            created_at: string | null
            updated_at: string | null
          }

          /**
           * Every webhook event Spree publishes, mapped to the record its `data`
           * carries. An interface, so an extension adds its own events by
           * declaration merging.
           */
          export interface WebhookEventMap {
          #{entries.map { |entry| map_line(entry) }.join("\n")}
          }
        TS
      end

      def map_line(entry)
        notes = []
        notes << "@deprecated Use `#{entry.deprecated_alias_of}` instead." if entry.deprecated?
        notes << 'Carries a live credential: delivered only to endpoints that name this event.' if entry.credential?
        comment = notes.map { |note| "  /** #{note} */\n" }.join
        "#{comment}  '#{entry.name}': #{type_name(entry)}"
      end

      def schemas_source
        schema_names = payload_type_names.map { |name| "#{name}Schema" }

        <<~TS
          #{HEADER}import { z } from 'zod'
          import {
          #{schema_names.map { |name| "  #{name}," }.join("\n")}
          } from '../../zod/generated'

          export const #{RECORD_REFERENCE}Schema = z.object({
            id: z.string(),
            created_at: z.string().nullable(),
            updated_at: z.string().nullable(),
          })

          /** The Zod schema for each webhook event's `data`, for `constructWebhookEvent`'s `schemas` option. */
          export const webhookEventSchemas = {
          #{entries.map { |entry| "  '#{entry.name}': #{type_name(entry)}Schema," }.join("\n")}
          } as const
        TS
      end
    end
  end
end
