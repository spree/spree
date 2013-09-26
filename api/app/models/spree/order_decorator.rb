Spree::Order.class_eval do
  def self.build_from_api(user, params)
    completed_at = params.delete(:completed_at)
    line_items = params.delete(:line_items_attributes) || {}
    shipments = params.delete(:shipments_attributes) || []
    payments = params.delete(:payments_attributes) || []
    adjustments = params.delete(:adjustments_attributes) || []

    ensure_country_id_from_api params[:ship_address_attributes]
    ensure_state_id_from_api params[:ship_address_attributes]

    ensure_country_id_from_api params[:bill_address_attributes]
    ensure_state_id_from_api params[:bill_address_attributes]

    order = create!(params)
    order.associate_user!(user)

    order.create_shipments_from_api(shipments)
    order.create_line_items_from_api(line_items)
    order.create_adjustments_from_api(adjustments)
    order.create_payments_from_api(payments)
    order.complete_from_api(completed_at)

    order.save!
    order.reload
  end

  def complete_from_api(completed_at)
    if completed_at
      self.completed_at = completed_at
      self.state = 'complete'
    end
  end

  def create_shipments_from_api(shipments_hash)
    shipments_hash.each do |s|
      begin
        shipment = shipments.build
        shipment.tracking = s[:tracking]
        shipment.stock_location = Spree::StockLocation.find_by_name!(s[:stock_location])

        inventory_units = s[:inventory_units] || []
        inventory_units.each do |iu|
          self.class.ensure_variant_id_from_api(iu)

          unit = shipment.inventory_units.build
          unit.order = self
          unit.variant_id = iu[:variant_id]
        end

        shipment.save!

        shipping_method = Spree::ShippingMethod.find_by_name!(s[:shipping_method])
        shipment.shipping_rates.create!(:shipping_method => shipping_method,
                                        :cost => s[:cost])
      rescue Exception => e
        raise "#{e.message} #{s}"
      end
    end
  end

  def create_payments_from_api(payments_hash)
    payments_hash.each do |p|
      begin
        payment = payments.build
        payment.amount = p[:amount].to_f
        payment.state = p.fetch(:state, 'completed')
        payment.payment_method = Spree::PaymentMethod.find_by_name!(p[:payment_method])
        payment.save!
      rescue Exception => e
        raise "#{e.message} #{p}"
      end
    end
  end

  def create_line_items_from_api(line_items_hash)
    line_items_hash.each_key do |k|
      begin
        line_item = line_items_hash[k]
        self.class.ensure_variant_id_from_api(line_item)

        extra_params = line_item.except(:variant_id, :quantity)
        line_item = self.contents.add(Spree::Variant.find(line_item[:variant_id]), line_item[:quantity])
        line_item.update_attributes(extra_params) unless extra_params.empty?
      rescue Exception => e
        raise "#{e.message} #{line_item}"
      end
    end
  end

  def create_adjustments_from_api(adjustments)
    adjustments.each do |a|
      begin
        adjustment = self.adjustments.build(:amount => a['amount'].to_f,
                                            :label => a['label'])
        adjustment.save!
        adjustment.finalize!
      rescue Exception => e
        raise "#{e.message} #{a}"
      end
    end
  end

  def self.ensure_variant_id_from_api(hash)
    begin
      unless hash[:variant_id].present?
        hash[:variant_id] = Spree::Variant.active.find_by_sku!(hash[:sku]).id
        hash.delete(:sku)
      end
    rescue Exception => e
      raise "#{e.message} #{hash}"
    end
  end

  def self.ensure_country_id_from_api(address)
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
      raise "#{e.message} #{search}"
    end
  end

  def self.ensure_state_id_from_api(address)
    return if address.nil? or address[:state_id].present? or address[:state].nil?

    begin
      search = {}
      if name = address[:state]['name']
        search[:name] = name
      elsif abbr = address[:state]['abbr']
        search[:abbr] = abbr.upcase
      end

      address.delete(:state)
      address[:state_id] = Spree::State.where(search).first!.id
    rescue Exception => e
      raise "#{e.message} #{search}"
    end
  end

  def update_line_items(line_item_params)
    return if line_item_params.blank?
    line_item_params.each do |id, attributes|
      self.line_items.find(id).update_attributes!(attributes)
    end
    self.ensure_updated_shipments
  end
end
