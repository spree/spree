module Admin::ZonesHelper
  def country_checked
    return object.class == "country" ? "checked = 'true'" : ""
  end
  def state_checked
    return object.class == "state" ? "checked = 'true'" : ""
  end
  def zone_checked
    return object.class == "zone" ? "checked = 'true'" : ""
  end
end