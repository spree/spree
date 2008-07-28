module Admin::ZonesHelper
  def country_checked
    return object.type == "country" ? "checked = 'true'" : ""
  end
  def state_checked
    return object.type == "state" ? "checked = 'true'" : ""
  end
  def zone_checked
    return object.type == "zone" ? "checked = 'true'" : ""
  end
end