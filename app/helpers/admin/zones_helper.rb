module Admin::ZonesHelper
  def country_checked
    return object.kind == "country" ? "checked = 'true'" : ""
  end
  def state_checked
    return object.kind == "state" ? "checked = 'true'" : ""
  end
  def zone_checked
    return object.kind == "zone" ? "checked = 'true'" : ""
  end
end
