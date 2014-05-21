Ember.Handlebars.helper "prettyDate", (date) ->
  moment(date).format(I18n.t('date_output.format'))

Ember.Handlebars.helper "prettyDateTime", (date) ->
  moment(date).format(I18n.t('time_output.format'))

i18n = (property, options) ->
  params = options.hash
  self = this

  #Support variable interpolation for our string
  Object.keys(params).forEach (key) ->
    params[key] = Em.Handlebars.get(self, params[key], options)

  return I18n.t(property, params)

Ember.Handlebars.registerHelper 'i18n', i18n
Handlebars.registerHelper 'i18n', i18n