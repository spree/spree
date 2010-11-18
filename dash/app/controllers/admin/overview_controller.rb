# this clas was inspired (heavily) from the mephisto admin architecture

class Admin::OverviewController < Admin::BaseController
  before_filter :check_json_authenticity, :only => :get_report_data
  #todo, add rss feed of information that is happening

  def index
    @show_dashboard = show_dashboard
    return unless @show_dashboard

    p = {:from => (Time.new().to_date  - 1.week).to_s(:db), :value => "Count"}
    @orders_by_day = orders_by_day(p)
    @orders_line_total = orders_line_total(p)
    @orders_total = orders_total(p)
    @orders_adjustment_total = orders_adjustment_total(p)
    @orders_credit_total = orders_credit_total(p)

    @best_selling_variants = best_selling_variants
    @top_grossing_variants = top_grossing_variants
    @last_five_orders = last_five_orders
    @biggest_spenders = biggest_spenders
    @out_of_stock_products = out_of_stock_products
    @best_selling_taxons = best_selling_taxons

    @pie_colors = [ "#0093DA", "#FF3500", "#92DB00", "#1AB3FF", "#FFB800"]
  end

  def get_report_data
    opts = case params[:name]
      when "7_days" then {:from => (Time.new().to_date - 1.week).to_s(:db)}
      when "14_days" then {:from => (Time.new().to_date - 2.week).to_s(:db)}
      when "this_month" then {:from => Date.new(Time.now.year, Time.now.month, 1).to_s(:db), :to => Date.new(Time.now.year, Time.now.month, -1).to_s(:db)}
      when "last_month" then {:from => Date.new(Time.now.year, Time.now.month - 1, 1).to_s(:db), :to => Date.new(Time.now.year, Time.now.month - 1, -1).to_s(:db)}
      when "this_year" then {:from => Date.new(Time.now.year, 1, 1).to_s(:db)}
      when "last_year" then {:from => Date.new(Time.now.year - 1, 1, 1).to_s(:db), :to => Date.new(Time.now.year - 1, 12, -1).to_s(:db)}
    end

    case params[:report]
      when "orders_by_day"
        opts[:value] = params[:value]

        render :js => "[[" + orders_by_day(opts).map { |day| "['#{day[0]}',#{day[1]}]" }.join(",") + "]]"
      when "orders_totals"
        render :js => [:orders_total => orders_total(opts).to_i, :orders_line_total => orders_line_total(opts).to_i,
          :orders_adjustment_total => orders_adjustment_total(opts).to_i, :orders_credit_total => orders_credit_total(opts).to_i ].to_json
    end
  end

  private
  def show_dashboard
    Order.count > 50
  end

  def conditions(params)
      if params.key? :to
        ["completed_at >= ? AND completed_at <= ?", params[:from], params[:to]]
      else
        ["completed_at >= ?", params[:from]]
      end
  end

  def fill_empty_entries(orders, params)
    from_date = params[:from].to_date
    to_date = (params[:to] || Time.now).to_date
    (from_date..to_date).each do |date|
      orders[date] ||= []
    end
  end

  def orders_by_day(params)

    if params[:value] == "Count"
      orders = Order.select(:created_at).where(conditions(params))
      orders = orders.group_by { |o| o.created_at.to_date }
      fill_empty_entries(orders, params)
      orders.keys.sort.map {|key| [key.strftime('%Y-%m-%d'), orders[key].size ]}
    else
      orders = Order.select([:created_at, :total]).where(conditions(params))
      orders = orders.group_by { |o| o.created_at.to_date }
      fill_empty_entries(orders, params)
      orders.keys.sort.map {|key| [key.strftime('%Y-%m-%d'), orders[key].inject(0){|s,o| s += o.total} ]}
    end
  end

  def orders_line_total(params)
    Order.sum(:item_total, :conditions => conditions(params))
  end

  def orders_total(params)
    Order.sum(:total, :conditions => conditions(params))
  end

  def orders_adjustment_total(params)
    Order.sum(:adjustment_total, :conditions => conditions(params))
  end

  def orders_credit_total(params)
    Order.sum(:credit_total, :conditions => conditions(params))
  end

  def best_selling_variants
    li = LineItem.sum(:quantity, :group => :variant_id, :limit => 5)
    variants = li.map do |v|
      variant = Variant.find(v[0])
      [variant.name, v[1] ]
    end
    variants.sort { |x,y| y[1] <=> x[1] }
  end

  def top_grossing_variants
    quantity = LineItem.sum(:quantity, :group => :variant_id, :limit => 5)
    prices = LineItem.sum(:price, :group => :variant_id, :limit => 5)
    variants = quantity.map do |v|
      variant = Variant.find(v[0])
      [variant.name, v[1] * prices[v[0]]]
    end

    variants.sort { |x,y| y[1] <=> x[1] }
  end

  def best_selling_taxons
    taxonomy = Taxonomy.last
    taxons =  Taxon.connection.select_rows("select t.name, count(li.quantity) from line_items li inner join variants v on
           li.variant_id = v.id inner join products p on v.product_id = p.id inner join products_taxons pt on p.id = pt.product_id
           inner join taxons t on pt.taxon_id = t.id where t.taxonomy_id = #{taxonomy.id} group by t.name order by count(li.quantity) desc limit 5;")
  end

  def last_five_orders
    orders = Order.includes(:line_items).where("completed_at IS NOT NULL").order("completed_at DESC").limit(5)
    orders.map do |o|
      qty = o.line_items.inject(0) {|sum,li| sum + li.quantity}

      [o.email, qty, o.total]
    end
  end

  def biggest_spenders
    spenders = Order.sum(:total, :group => :user_id, :limit => 5, :order => "sum(total) desc", :conditions => "completed_at is not null and user_id is not null")
    spenders = spenders.map do |o|
      orders = User.find(o[0]).orders
      qty = orders.size

      [orders.first.email, qty, o[1]]

    end

    spenders.sort { |x,y| y[2] <=> x[2] }
  end

  def out_of_stock_products
    Product.where(:count_on_hand => 0).limit(5)
  end
end
