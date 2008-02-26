module Admin::OverviewHelper
  def render_ordes(orders, later=false)
    text = []
    if orders.any?
      # TODO: handle Order objects, create partials for this
      # orders.each_with_index {|order, i| text << render(:partial => "#{order.mode}_event", :locals => {:order => order, :shaded => (i % 2 > 0), :later => later}) }
    else
      text << %w(<li class="order-none shade">No orders</li>)
    end
    %(<ul class="orders">#{text.join}</ul>)
  end
end
