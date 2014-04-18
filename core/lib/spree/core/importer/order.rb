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

            order = Spree::Order.create!
            order.associate_user!(user)

            create_shipments_from_params(params.delete(:shipments_attributes), order)
            create_line_items_from_params(params.delete(:line_items_attributes),order)
            create_adjustments_from_params(params.delete(:adjustments_attributes), order)
            create_payments_from_params(params.delete(:payments_attributes), order)

            if(completed_at = params.delete(:completed_at))
              order.completed_at = completed_at
              order.state = 'complete'
            end

            order.update_attributes!(params)
            # Really ensure that the order totals are correct
            order.update_totals
            order.persist_totals
            order.reload
          rescue Exception => e
            order.destroy if order && order.persisted?
            raise e.message
          end
        end

        def self.create_shipments_from_params(shipments_hash, order)
          return [] unless shipments_hash
          shipments_hash.each do |s|
            begin
              shipment = order.shipments.build
              shipment.tracking = s[:tracking]
              shipment.stock_location = Spree::StockLocation.find_by_name!(s[:stock_location])

              inventory_units = s[:inventory_units] || []
              inventory_units.each do |iu|
                ensure_variant_id_from_params(iu)

                unit = shipment.inventory_units.build
                unit.line_item = order.line_items.find_by_variant_id(iu[:variant_id])
                unit.order = order
                unit.variant_id = iu[:variant_id]
              end

              shipment.save!

              shipping_method = Spree::ShippingMethod.find_by_name!(s[:shipping_method])
              rate = shipment.shipping_rates.create!(:shipping_method => shipping_method,
                                                     :cost => s[:cost])
              shipment.selected_shipping_rate_id = rate.id

            rescue Exception => e
              raise "Order import shipments: #{e.message} #{s}"
            end
          end
        end

        def self.create_line_items_from_params(line_items_hash, order)
          return {} unless line_items_hash
          line_items_hash.each_key do |k|
            begin
              line_item = line_items_hash[k]
              ensure_variant_id_from_params(line_item)

              extra_params = line_item.except(:variant_id, :quantity)
              line_item = order.contents.add(Spree::Variant.find(line_item[:variant_id]), line_item[:quantity])
              line_item.update_attributes(extra_params) unless extra_params.empty?
            rescue Exception => e
              raise "Order import line items: #{e.message} #{line_item}"
            end
          end
        end

        def self.create_adjustments_from_params(adjustments, order)
          return [] unless adjustments
          adjustments.each do |a|
            begin
              adjustment = order.adjustments.build(:amount => a[:amount].to_f,
                                                  :label => a[:label])
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
              payment = order.payments.build
              payment.amount = p[:amount].to_f
              payment.state = p.fetch(:state, 'completed')
              payment.payment_method = Spree::PaymentMethod.find_by_name!(p[:payment_method])
              payment.save!
            rescue Exception => e
              raise "Order import payments: #{e.message} #{p}"
            end
          end
        end

        def self.ensure_variant_id_from_params(hash)
          begin
            unless hash[:variant_id].present?
              hash[:variant_id] = Spree::Variant.active.find_by_sku!(hash[:sku]).id
              hash.delete(:sku)
            end
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
