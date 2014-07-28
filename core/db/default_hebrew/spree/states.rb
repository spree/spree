country = Spree::Country.find_by(name: 'Israel')

Spree::State.create!([
  { name: 'ירושלים', abbr: 'JR', country: country },
  { name: 'תל אביב והמרכז', abbr: 'TLV', country: country },
  { name: 'חיפה והצפון', abbr: 'NR', country: country },
  { name: 'שפלה והדרום', abbr: 'STH', country: country },
  { name: 'השרון', abbr: 'SHR', country: country }
])
