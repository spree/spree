module Spree
  module Api
    module V3
      module Admin
        # Decorates a Spree::Reporting::Result for the wire: money display
        # strings, ISO ranges, and dimension hydration — raw group keys become
        # { id, label, meta } display payloads via batched, store-scoped
        # lookups (a product row carries its thumbnail; a customer row its
        # profile link id).
        class ReportingResultSerializer
          attr_reader :result, :store, :params

          def initialize(result, store:, params: {})
            @result = result
            @store = store
            @params = params
          end

          def to_h
            {
              meta: meta,
              totals: result.totals.to_h { |name, payload| [name, metric_payload(name, payload)] },
              rows: result.rows.map do |row|
                {
                  dimensions: hydrate_dimensions(row[:dimensions]),
                  metrics: row[:metrics].to_h { |name, payload| [name, metric_payload(name, payload)] }
                }
              end
            }
          end

          private

          def meta
            {
              currency: result.meta[:currency],
              time_range: iso_range(result.meta[:time_range]),
              previous_time_range: iso_range(result.meta[:previous_time_range]),
              metrics: result.meta[:metrics],
              dimensions: result.meta[:dimensions]
            }
          end

          def iso_range(range)
            return unless range

            { since: range.first.iso8601, until: range.last.iso8601 }
          end

          def metric_payload(name, payload)
            output = payload.dup
            output[:display] = money(payload[:value]) if Spree.reporting.metrics[name]&.money?
            output
          end

          def money(amount)
            Spree::Money.new(amount, currency: result.meta[:currency]).to_s
          end

          def hydrate_dimensions(dimensions)
            dimensions.to_h do |name, raw|
              definition = Spree.reporting.dimension!(name)
              [name, dimension_value(definition, raw)]
            end
          end

          def dimension_value(definition, raw)
            return raw if definition.lookup.blank?

            hydrator = hydrators[definition.lookup] || {}
            hydrator[raw] || { id: nil, label: raw.to_s, meta: {} }
          end

          # One batched lookup per hydrated dimension across all rows.
          def hydrators
            @hydrators ||= begin
              keys = Hash.new { |h, k| h[k] = [] }
              result.rows.each do |row|
                row[:dimensions].each do |name, raw|
                  definition = Spree.reporting.dimension!(name)
                  keys[definition.lookup] << raw if definition.lookup.present?
                end
              end

              {
                channel: hydrate_channels(keys[:channel]),
                customer: hydrate_customers(keys[:customer]),
                category: hydrate_categories(keys[:category]),
                product: hydrate_products(keys[:product])
              }
            end
          end

          def hydrate_channels(ids)
            return {} if ids.empty?

            store.channels.where(id: ids.uniq).to_h do |channel|
              [channel.id, { id: channel.prefixed_id, label: channel.name, meta: { code: channel.code } }]
            end
          end

          def hydrate_customers(emails)
            return {} if emails.empty?

            users = store.customers.distinct.where(email: emails.uniq).index_by(&:email)
            emails.uniq.to_h do |email|
              user = users[email]
              [email, { id: user&.prefixed_id, label: user&.full_name.presence || email, meta: { email: email } }]
            end
          end

          def hydrate_categories(ids)
            return {} if ids.empty?

            store.categories.where(id: ids.uniq).to_h do |category|
              [category.id, { id: category.prefixed_id, label: category.name, meta: {} }]
            end
          end

          def hydrate_products(ids)
            return {} if ids.empty?

            serializer = Spree.api.admin_product_serializer
            store.products.with_deleted.includes(:primary_media).where(id: ids.uniq).to_h do |product|
              serialized = serializer.new(product, params: params).to_h
              [product.id, {
                id: serialized['id'],
                label: serialized['name'],
                meta: {
                  slug: serialized['slug'],
                  thumbnail_url: serialized['thumbnail_url'],
                  price: serialized.dig('price', 'display_amount')
                }
              }]
            end
          end
        end
      end
    end
  end
end
