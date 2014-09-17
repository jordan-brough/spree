Spree::Core::Engine.draw_routes

Spree::Core::Engine.routes.draw do
  mount Spree::Frontend::Engine, at: '/' if defined?(Spree::Frontend)
end
