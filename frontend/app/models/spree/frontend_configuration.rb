module Spree
  class FrontendConfiguration < Preferences::Configuration
    preference :locale, :string, :default => Rails.application.config.i18n.default_locale
    preference :hide_confirm_step, :boolean, default: false
  end
end
