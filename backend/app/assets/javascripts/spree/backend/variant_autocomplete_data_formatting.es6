// eslint-disable-next-line no-unused-vars
function buildJsonDataForVariants (json) {
  const variantsAndImages = json.included
  variantsAndImages.forEach(item => addImagesToVariants(item))
  variantsAndImages.forEach(item => addStockLocationNameToStockItems(item))
  variantsAndImages.forEach(item => addAvailabiltyToStockItems(item))

  function addImagesToVariants (item) {
    if (item.type === 'variant' && item.relationships.images.data[0]) {
      const attachedImageId = item.relationships.images.data[0].id
      const imgPath = _.find(json.included, function (va) {
        return va.type === 'image' && va.id === attachedImageId
      })
      item.attributes.image_path = imgPath.attributes.styles[2].url
    }
  }

  function addStockLocationNameToStockItems (item) {
    if (item.type === 'variant' && item.relationships.stock_items.data) {
      const stockItems = item.attributes.stock_items

      stockItems.forEach(function (si) {
        const stocklocationName = stockLocationName(si.stock_location_id, item)
        si.stock_location_name = stocklocationName
      })
    }
  }

  function stockLocationName (stockLocationId, item) {
    const sln = []
    const stockLocations = item.attributes.stock_locations

    stockLocations.forEach(function (sl) {
      if (sl.id === stockLocationId) {
        sln.push(sl.name)
      }
    })
    return sln[0]
  }

  function addAvailabiltyToStockItems (item) {
    if (item.type === 'variant' && item.relationships.stock_items.data) {
      const stockItems = item.attributes.stock_items

      stockItems.forEach(function (si) {
        if (si.count_on_hand > 0 || si.backorderable === true) {
          si.is_available = true
        } else {
          si.is_available = false
        }
      })
    }
  }
}
