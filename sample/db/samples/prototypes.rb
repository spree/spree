Spree::Sample.load_sample('properties')

prototypes = [
  {
    name: 'Сорочка',
    properties: ['Виробник', 'Бренд', 'Модель', 'Довжина', 'Зроблено з', 'Матеріал', 'Формат', 'Стать']
  },
  {
    name: 'Сумка',
    properties: ['Тип', 'Розмір', 'Матеріал']
  },
  {
    name: 'Кружки',
    properties: ['Розмір', 'Тип']
  }
]

prototypes.each do |prototype_attrs|
  prototype = Spree::Prototype.where(name: prototype_attrs[:name]).first_or_create!
  prototype_attrs[:properties].each do |property_presentation|
    property = Spree::Property.find_by!(presentation: property_presentation)
    prototype.properties << property unless prototype.properties.include?(property)
  end
end
