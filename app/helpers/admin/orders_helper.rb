module Admin::OrdersHelper

  # Renders all the txn partials that may have been specified in the extensions
  def render_txn_partials(order)
    @txn_partials.inject("") do |extras, partial|
      extras += render :partial => partial, :locals => {:payment => order}
    end
  end

  # Renders all the extension partials that may have been specified in the extensions
  def event_links
    links = []
    @order_events.sort.each do |event|
      if @order.send("can_#{event}?")
        links << button_link_to(t(event), fire_admin_order_url(@order, :e => event),
                                { :method => :put, :confirm => t("order_sure_want_to", :event => t(event)) })
      end
    end
    links.join('&nbsp;')
  end

  def generate_html(form_builder, method, options = {})
    options[:object] ||= form_builder.object.class.reflect_on_association(method).klass.new
    options[:partial] ||= method.to_s.singularize
    options[:form_builder_local] ||= :f

    form_builder.fields_for(method, options[:object], :child_index => 'NEW_RECORD') do |f|
      render(:partial => options[:partial], :locals => { options[:form_builder_local] => f })
    end
  end

  def generate_template(form_builder, method, options = {})
    escape_javascript generate_html(form_builder, method, options)
  end
end
