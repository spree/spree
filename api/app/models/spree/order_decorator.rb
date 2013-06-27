Spree::Order.class_eval do
  def self.build_from_api(user, params)
    line_items = params.delete(:line_items_attributes) || []
    ensure_country_id_from_api params[:ship_address_attributes]
    ensure_state_id_from_api params[:ship_address_attributes]

    order = create(params)

    unless line_items.empty?
      line_items.each_key do |k|
        line_item = line_items[k]

        ensure_variant_id_from_api(line_item)

        order.contents.add(Spree::Variant.find(line_item[:variant_id]), line_item[:quantity])
      end
    end

    order
  end

  def self.ensure_country_id_from_api(address)
    return if address.nil? or address[:country_id] or address[:country].nil?

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

  def self.ensure_state_id_from_api(address)
    return if address.nil? or address[:state_id] or address[:state].nil?

    search = {}
    if name = address[:state]['name']
      search[:name] = name
    elsif abbr = address[:state]['abbr']
      search[:abbr] = abbr.upcase
    end

    address.delete(:state)
    address[:state_id] = Spree::State.where(search).first!.id
  end

  def self.ensure_variant_id_from_api(line_item)
    unless line_item[:variant_id]
      line_item[:variant_id] = Spree::Variant.find_by_sku(line_item[:sku]).id if line_item.has_key?(:sku)
    end
  end

  def update_line_items(line_item_params)
    return if line_item_params.blank?
    line_item_params.each do |id, attributes|
      self.line_items.find(id).update_attributes!(attributes)
    end
  end
end
