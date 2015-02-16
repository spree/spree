module Spree
  module Core
    module Importer
      class Order

        def self.import(user, params)
          ensure_country_id_from_params params[:ship_address_attributes]
          ensure_state_id_from_params params[:ship_address_attributes]
          ensure_country_id_from_params params[:bill_address_attributes]
          ensure_state_id_from_params params[:bill_address_attributes]

          create_params = params.slice :currency
          order = Spree::Order.create! create_params
          order.associate_user!(user)

          shipments_attrs = params.delete(:shipments_attributes)

          create_shipments_from_params(shipments_attrs, order)
          create_line_items_from_params(params.delete(:line_items_attributes), order)
          create_shipments_from_params(params.delete(:shipments_attributes), order)
          create_adjustments_from_params(params.delete(:adjustments_attributes), order)
          create_payments_from_params(params.delete(:payments_attributes), order)

          if completed_at = params.delete(:completed_at)
            order.completed_at = completed_at
            order.state = 'complete'
          end

          params.delete :user_id unless user.try(:has_spree_role?, "admin") && params.key?(:user_id)

          order.update_attributes!(params)

          order.create_proposed_shipments unless shipments_attrs.present?

          # Really ensure that the order totals & states are correct
          order.updater.update
          if shipments_attrs.present?
            order.shipments.each_with_index do |shipment, index|
              shipment_cost = shipments_attrs[index][:cost]
              shipment.update_columns(cost: shipment_cost.to_f) if shipment_cost.present?
            end
          end
          order.reload
        ensure
          order.destroy if order && order.persisted?
        end

        def self.create_shipments_from_params(shipments_hash, order)
          return [] unless shipments_hash

          line_items = order.line_items
          shipments_hash.each do |s|
            shipment = order.shipments.build
            shipment.tracking       = s[:tracking]
            shipment.stock_location = Spree::StockLocation.find_by_admin_name(s[:stock_location]) || Spree::StockLocation.find_by_name!(s[:stock_location])

            inventory_units = s[:inventory_units] || []
            inventory_units.each do |iu|
              ensure_variant_id_from_params(iu)

              unit = shipment.inventory_units.build
              unit.order = order

              # Spree expects a Inventory Unit to always reference a line
              # item and variant otherwise users might get exceptions when
              # trying to view these units. Note the Importer might not be
              # able to find the line item if line_item.variant_id |= iu.variant_id
              unit.variant_id = iu[:variant_id]
              unit.line_item_id = line_items.select do |l|
                l.variant_id.to_i == iu[:variant_id].to_i
              end.first.try(:id)
            end

            # Mark shipped if it should be.
            if s[:shipped_at].present?
              shipment.shipped_at = s[:shipped_at]
              shipment.state      = 'shipped'
              shipment.inventory_units.each do |unit|
                unit.state = 'shipped'
              end
            end

            shipment.save!

            shipping_method = Spree::ShippingMethod.find_by_name(s[:shipping_method]) || Spree::ShippingMethod.find_by_admin_name!(s[:shipping_method])
            rate = shipment.shipping_rates.create!(shipping_method: shipping_method, cost: s[:cost])
            shipment.selected_shipping_rate_id = rate.id
            shipment.update_amounts
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
              extra_params = line_items[k].except(:variant_id, :quantity, :sku)
              line_item = ensure_variant_id_from_params(line_items[k])
              variant = Spree::Variant.find(line_item[:variant_id])
              line_item = order.contents.add(variant, line_item[:quantity])
              # Raise any errors with saving to prevent import succeeding with line items
              # failing silently.
              extra_params.present? ? line_item.update_attributes!(extra_params) : line_item.save!
            end
          when Array
            line_items.each do |line_item|
              extra_params = line_item.except(:variant_id, :quantity, :sku)
              line_item = ensure_variant_id_from_params(line_item)
              variant = Spree::Variant.find(line_item[:variant_id])
              line_item = order.contents.add(variant, line_item[:quantity])
              # Raise any errors with saving to prevent import succeeding with line items
              # failing silently.
              extra_params.present? ? line_item.update_attributes!(extra_params) : line_item.save!
            end
          end
        end

        def self.create_adjustments_from_params(adjustments, order)
          return [] unless adjustments
          adjustments.each do |a|
            adjustment = order.adjustments.build(
              order:  order,
              amount: a[:amount].to_f,
              label:  a[:label]
            )
            adjustment.save!
            adjustment.close!
          end
        end

        def self.create_payments_from_params(payments_hash, order)
          return [] unless payments_hash
          payments_hash.each do |p|
            payment = order.payments.build order: order
            payment.amount = p[:amount].to_f
            # Order API should be using state as that's the normal payment field. spree_wombat
            # serializes payment state as status so imported orders should fall back to status field
            payment.state = p[:state] || p[:status] || 'completed'
            payment.payment_method = Spree::PaymentMethod.find_by_name!(p[:payment_method])
            payment.source = create_source_payment_from_params(p[:source], payment) if p[:source]
            payment.save!
          end
        end

        def self.create_source_payment_from_params(source_hash, payment)
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
        end

        def self.ensure_variant_id_from_params(hash)
          sku = hash.delete(:sku)
          unless hash[:variant_id].present?
            hash[:variant_id] = Spree::Variant.active.find_by!(sku: sku).id
          end
          hash
        end

        def self.ensure_country_id_from_params(address)
          return if address.nil? or address[:country_id].present? or address[:country].nil?

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
        end

        def self.ensure_state_id_from_params(address)
          return if address.nil? or address[:state_id].present? or address[:state].nil?

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
        end
      end
    end
  end
end
