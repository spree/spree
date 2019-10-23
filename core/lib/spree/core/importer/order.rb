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

          create_line_items_from_params(params.delete(:line_items_attributes), order)
          create_shipments_from_params(shipments_attrs, order)
          create_adjustments_from_params(params.delete(:adjustments_attributes), order)
          create_payments_from_params(params.delete(:payments_attributes), order)

          if completed_at = params.delete(:completed_at)
            order.completed_at = completed_at
            order.state = 'complete'
          end

          params.delete(:user_id) unless user.try(:has_spree_role?, 'admin') && params.key?(:user_id)

          order.update!(params)

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
          order.destroy if order&.persisted?
          raise e.message
        end

        def self.create_shipments_from_params(shipments_hash, order)
          return [] unless shipments_hash

          shipments_hash.each do |s|
            shipment = order.shipments.build
            shipment.tracking       = s[:tracking]
            shipment.stock_location = Spree::StockLocation.find_by(admin_name: s[:stock_location]) ||
              Spree::StockLocation.find_by!(name: s[:stock_location])
            inventory_units = create_inventory_units_from_order_and_params(order, s[:inventory_units])

            inventory_units.each do |inventory_unit|
              inventory_unit.shipment = shipment

              if s[:shipped_at].present?
                inventory_unit.pending = false
                inventory_unit.state = 'shipped'
              end

              inventory_unit.save!
            end

            if s[:shipped_at].present?
              shipment.shipped_at = s[:shipped_at]
              shipment.state      = 'shipped'
            end

            shipment.save!

            shipping_method = Spree::ShippingMethod.find_by(name: s[:shipping_method]) ||
              Spree::ShippingMethod.find_by!(admin_name: s[:shipping_method])
            rate = shipment.shipping_rates.create!(shipping_method: shipping_method, cost: s[:cost])

            shipment.selected_shipping_rate_id = rate.id
            shipment.update_amounts

            adjustments = s.delete(:adjustments_attributes)
            create_adjustments_from_params(adjustments, order, shipment)
          rescue Exception => e
            raise "Order import shipments: #{e.message} #{s}"
          end
        end

        def self.create_inventory_units_from_order_and_params(order, inventory_unit_params)
          inventory_unit_params.each_with_object([]) do |inventory_unit_param, inventory_units|
            ensure_variant_id_from_params(inventory_unit_param)
            existing = inventory_units.detect { |unit| unit.variant_id == inventory_unit_param[:variant_id] }
            if existing
              existing.quantity += 1
            else
              line_item = order.line_items.detect { |ln| ln.variant_id == inventory_unit_param[:variant_id] }
              inventory_units << InventoryUnit.new(line_item: line_item, order_id: order.id, variant: line_item.variant, quantity: 1)
            end
          end
        end

        def self.create_line_items_from_params(line_items, order)
          return {} unless line_items

          line_items.each do |line_item|
            adjustments = line_item.delete(:adjustments_attributes)
            extra_params = line_item.except(:variant_id, :quantity, :sku)
            line_item = ensure_variant_id_from_params(line_item)
            variant = Spree::Variant.find(line_item[:variant_id])
            line_item = Cart::AddItem.call(order: order, variant: variant, quantity: line_item[:quantity]).value
            # Raise any errors with saving to prevent import succeeding with line items
            # failing silently.
            if extra_params.present?
              line_item.update!(extra_params)
            else
              line_item.save!
            end
            create_adjustments_from_params(adjustments, order, line_item)
          rescue Exception => e
            raise "Order import line items: #{e.message} #{line_item}"
          end
        end

        def self.create_adjustments_from_params(adjustments, order, adjustable = nil)
          return [] unless adjustments

          adjustments.each do |a|
            adjustment = (adjustable || order).adjustments.build(
              order: order,
              amount: a[:amount].to_f,
              label: a[:label],
              source_type: source_type_from_adjustment(a)
            )
            adjustment.save!
            adjustment.close!
          rescue Exception => e
            raise "Order import adjustments: #{e.message} #{a}"
          end
        end

        def self.create_payments_from_params(payments_hash, order)
          return [] unless payments_hash

          payments_hash.each do |p|
            payment = order.payments.build order: order
            payment.amount = p[:amount].to_f
            # Order API should be using state as that's the normal payment field.
            # spree_wombat serializes payment state as status so imported orders should fall back to status field.
            payment.state = p[:state] || p[:status] || 'completed'
            payment.created_at = p[:created_at] if p[:created_at]
            payment.payment_method = Spree::PaymentMethod.find_by!(name: p[:payment_method])
            payment.source = create_source_payment_from_params(p[:source], payment) if p[:source]
            payment.save!
          rescue Exception => e
            raise "Order import payments: #{e.message} #{p}"
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
        rescue Exception => e
          raise "Order import source payments: #{e.message} #{source_hash}"
        end

        def self.ensure_variant_id_from_params(hash)
          sku = hash.delete(:sku)
          unless hash[:variant_id].present?
            hash[:variant_id] = Spree::Variant.active.find_by!(sku: sku).id
          end
          hash
        rescue ActiveRecord::RecordNotFound => e
          raise "Ensure order import variant: Variant w/SKU #{sku} not found."
        rescue Exception => e
          raise "Ensure order import variant: #{e.message} #{hash}"
        end

        def self.ensure_country_id_from_params(address)
          return if address.nil? || address[:country_id].present? || address[:country].nil?

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
          return if address.nil? || address[:state_id].present? || address[:state].nil?

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

        def self.source_type_from_adjustment(adjustment)
          if adjustment[:tax]
            'Spree::TaxRate'
          elsif adjustment[:promotion]
            'Spree::PromotionAction'
          end
        end
      end
    end
  end
end
