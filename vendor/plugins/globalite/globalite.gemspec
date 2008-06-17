Gem::Specification.new do |s|
  s.name = "globalite"
  s.version = "0.5.0"
  s.date = "2008-06-02"
  s.summary = "Globalite is meant to be a breed of the best internationalization/localization plugins available for Rails."
  s.email = "mattaimonetti@gmail.com"
  s.homepage = "http://github.com/mojombo/grit"
  s.description = "Easy UI localization, Rails localization. (Localization of the core functions from rails), Simple yet powerful solution for user content availability in multiple languages."
  s.has_rdoc = true
  s.authors = ["Matt Aimonetti"]
  s.files = ['lang/rails/de-DE.yml', 'lang/rails/en-UK.yml', 'lang/rails/en-US.yml', 'lang/rails/es-AR.yml', 'lang/rails/es-ES.yml', 'lang/rails/fi-FI.yml', 'lang/rails/fr-FR.yml', 'lang/rails/hu-HU.yml', 'lang/rails/it.yml', 'lang/rails/nl-NL.yml', 'lang/rails/pl-PL.yml', 'lang/rails/pt-BR.yml', 'lang/rails/pt-PT.yml', 'lang/rails/ru-RU.yml', 'lang/rails/zh-CN.yml', 'lang/rails/sr-CP.yml', 'lang/rails/sr-SR.yml', 'lang/rails/tr.yml',  'lang/rails/zh-HK.yml', 'lang/rails/zh-TW.yml', 'lang/rails/zh-CN.yml', 'lib/globalite/l10n.rb', 'lib/globalite/locale.rb', 'lib/rails/core_ext.rb', 'lib/rails/localization.rb', 'lib/rails/localized_action_view.rb', 'lib/rails/localized_active_record.rb', 'lib/globalite.rb', ]
  s.test_files = ["spec/helpers/spec_helper.rb", "spec/lang/rails/zz.yml", "spec/lang/ui/es.yml", "spec/lang/ui/en-UK.yml", "spec/lang/ui/en-US.yml", "spec/lang/ui/fr-FR.yml", "spec/core_localization_spec.rb", "spec/l10n_spec.rb" ]
  s.extra_rdoc_files = ["README"]
end
