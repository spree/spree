module Spree
  module Core
    module Importer
      class Order

        def self.import(user, params)
          begin
            ensure_country_id_from_params params[:ship_address_attributes]
            ensure_state_id_from_params params[:ship_address_attributes]
            ensure_country_id_from_params params[:bill_address_attributes]
            ensure_state_id_from_params params[:bill_address_attributes]

            create_params = params.slice :currency
            order = Spree::Order.create! create_params
            order.associate_user!(user)

            shipments_attrs = params.delete(:shipments_attributes)

            create_line_items_from_params(params.delete(:line_items_attributes),order)
            create_shipments_from_params(shipments_attrs, order)
            create_adjustments_from_params(params.delete(:adjustments_attributes), order)
            create_payments_from_params(params.delete(:payments_attributes), order)

            if completed_at = params.delete(:completed_at)
              order.completed_at = completed_at
              order.state = 'complete'
            end

            params.delete(:user_id) unless user.try(:has_spree_role?, "admin") && params.key?(:user_id)

            order.update_attributes!(params)

            order.create_proposed_shipments unless shipments_attrs.present?

            # Really ensure that the order totals & states are correct
            order.updater.update
            if shipments_attrs.present?
              order.shipments.each_with_index do |shipment, index|
                shipment.update_columns(cost: shipments_attrs[index][:cost].to_f) if shipments_attrs[index][:cost].present?
              end
            end
            order.reload
          rescue Exception => e
            order.destroy if order && order.persisted?
            raise e.message
          end
        end

        def self.create_shipments_from_params(shipments_hash, order)
          return [] unless shipments_hash

          inventory_units = Spree::Stock::InventoryUnitBuilder.new(order).units

          shipments_hash.each do |s|
            begin
              shipment = order.shipments.build
              shipment.tracking       = s[:tracking]
              shipment.stock_location = Spree::StockLocation.find_by_admin_name(s[:stock_location]) || Spree::StockLocation.find_by_name!(s[:stock_location])

              shipment_units = s[:inventory_units] || []
              shipment_units.each do |su|
                ensure_variant_id_from_params(su)

                inventory_unit = inventory_units.detect { |iu| iu.variant_id.to_i == su[:variant_id].to_i }

                if inventory_unit.present?
                  inventory_unit.shipment = shipment

                  if s[:shipped_at].present?
                    inventory_unit.pending = false
                    inventory_unit.state = 'shipped'
                  end

                  inventory_unit.save!

                  # Don't assign shipments to this inventory unit more than once
                  inventory_units.delete(inventory_unit)
                end
              end

              if s[:shipped_at].present?
                shipment.shipped_at = s[:shipped_at]
                shipment.state      = 'shipped'
              end

              shipment.save!

              shipping_method = Spree::ShippingMethod.find_by_name(s[:shipping_method]) || Spree::ShippingMethod.find_by_admin_name!(s[:shipping_method])
              rate = shipment.shipping_rates.create!(shipping_method: shipping_method, cost: s[:cost])

              shipment.selected_shipping_rate_id = rate.id
              shipment.update_amounts

            rescue Exception => e
              raise "Order import shipments: #{e.message} #{s}"
            end
          end
        end

        def self.create_line_items_from_params(line_items, order)
          return {} unless line_items
          case line_items
          when Hash
            ActiveSupport::Deprecation.warn(<<-EOS, caller)
              Passing a hash is now deprecated and will be removed in Spree 3.1.
              It is recommended that you pass it as an array instead.

              New Syntax:

              {
                "order": {
                  "line_items": [
                    { "variant_id": 123, "quantity": 1 },
                    { "variant_id": 456, "quantity": 1 }
                  ]
                }
              }

              Old Syntax:

              {
                "order": {
                  "line_items": {
                    "1": { "variant_id": 123, "quantity": 1 },
                    "2": { "variant_id": 123, "quantity": 1 }
                  }
                }
              }
            EOS

            line_items.each_key do |k|
              begin
                extra_params = line_items[k].except(:variant_id, :quantity, :sku)
                line_item = ensure_variant_id_from_params(line_items[k])
                variant = Spree::Variant.find(line_item[:variant_id])
                line_item = order.contents.add(variant, line_item[:quantity])
                # Raise any errors with saving to prevent import succeeding with line items
                # failing silently.
                if extra_params.present?
                  line_item.update_attributes!(extra_params)
                else
                  line_item.save!
                end
              rescue Exception => e
                raise "Order import line items: #{e.message} #{line_item}"
              end
            end
          when Array
            line_items.each do |line_item|
              begin
                extra_params = line_item.except(:variant_id, :quantity, :sku)
                line_item = ensure_variant_id_from_params(line_item)
                variant = Spree::Variant.find(line_item[:variant_id])
                line_item = order.contents.add(variant, line_item[:quantity])
                # Raise any errors with saving to prevent import succeeding with line items
                # failing silently.
                if extra_params.present?
                  line_item.update_attributes!(extra_params)
                else
                  line_item.save!
                end
              rescue Exception => e
                raise "Order import line items: #{e.message} #{line_item}"
              end
            end
          end
        end

        def self.create_adjustments_from_params(adjustments, order)
          return [] unless adjustments
          adjustments.each do |a|
            begin
              adjustment = order.adjustments.build(
                order:  order,
                amount: a[:amount].to_f,
                label:  a[:label]
              )
              adjustment.save!
              adjustment.close!
            rescue Exception => e
              raise "Order import adjustments: #{e.message} #{a}"
            end
          end
        end

        def self.create_payments_from_params(payments_hash, order)
          return [] unless payments_hash
          payments_hash.each do |p|
            begin
              payment = order.payments.build order: order
              payment.amount = p[:amount].to_f
              # Order API should be using state as that's the normal payment field.
              # spree_wombat serializes payment state as status so imported orders should fall back to status field.
              payment.state = p[:state] || p[:status] || 'completed'
              payment.created_at = p[:created_at] if p[:created_at]
              payment.payment_method = Spree::PaymentMethod.find_by_name!(p[:payment_method])
              payment.source = create_source_payment_from_params(p[:source], payment) if p[:source]
              payment.save!
            rescue Exception => e
              raise "Order import payments: #{e.message} #{p}"
            end
          end
        end

        def self.create_source_payment_from_params(source_hash, payment)
          begin
            Spree::CreditCard.create(
              month: source_hash[:month],
              year: source_hash[:year],
              cc_type: source_hash[:cc_type],
              last_digits: source_hash[:last_digits],
              name: source_hash[:name],
              payment_method: payment.payment_method,
              gateway_customer_profile_id: source_hash[:gateway_customer_profile_id],
              gateway_payment_profile_id: source_hash[:gateway_payment_profile_id],
              imported: true
            )
          rescue Exception => e
            raise "Order import source payments: #{e.message} #{source_hash}"
          end
        end

        def self.ensure_variant_id_from_params(hash)
          begin
            sku = hash.delete(:sku)
            unless hash[:variant_id].present?
              hash[:variant_id] = Spree::Variant.active.find_by_sku!(sku).id
            end
            hash
          rescue ActiveRecord::RecordNotFound => e
            raise "Ensure order import variant: Variant w/SKU #{sku} not found."
          rescue Exception => e
            raise "Ensure order import variant: #{e.message} #{hash}"
          end
        end

        def self.ensure_country_id_from_params(address)
          return if address.nil? or address[:country_id].present? or address[:country].nil?

          begin
            search = {}
            if name = address[:country]['name']
              search[:name] = name
            elsif iso_name = address[:country]['iso_name']
              search[:iso_name] = iso_name.upcase
            elsif iso = address[:country]['iso']
              search[:iso] = iso.upcase
            elsif iso3 = address[:country]['iso3']
              search[:iso3] = iso3.upcase
            end

            address.delete(:country)
            address[:country_id] = Spree::Country.where(search).first!.id

          rescue Exception => e
            raise "Ensure order import address country: #{e.message} #{search}"
          end
        end

        def self.ensure_state_id_from_params(address)
          return if address.nil? or address[:state_id].present? or address[:state].nil?

          begin
            search = {}
            if name = address[:state]['name']
              search[:name] = name
            elsif abbr = address[:state]['abbr']
              search[:abbr] = abbr.upcase
            end

            address.delete(:state)
            search[:country_id] = address[:country_id]

            if state = Spree::State.where(search).first
              address[:state_id] = state.id
            else
              address[:state_name] = search[:name] || search[:abbr]
            end
          rescue Exception => e
            raise "Ensure order import address state: #{e.message} #{search}"
          end
        end

      end
    end
  end
end
