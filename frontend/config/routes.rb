Spree::Frontend::Engine.routes.draw do

  root :to => '/spree/home#index'

  resources :products, :only => [:index, :show], to: '/spree/products'

  get '/locale/set', :to => '/spree/locale#set'

  # non-restful checkout stuff
  patch '/checkout/update/:state', :to => '/spree/checkout#update', :as => :update_checkout
  get '/checkout/:state', :to => '/spree/checkout#edit', :as => :checkout_state
  get '/checkout', :to => '/spree/checkout#edit' , :as => :checkout

  populate_redirect = redirect do |params, request|
    request.flash[:error] = Spree.t(:populate_get_error)
    request.referer || '/cart'
  end

  get '/orders/populate', :to => populate_redirect
  get '/orders/:id/token/:token' => '/spree/orders#show', :as => :token_order

  resources :orders, :except => [:index, :new, :create, :destroy], to: '/spree/orders' do
    post :populate, :on => :collection
  end

  get '/cart', :to => '/spree/orders#edit', :as => :cart
  patch '/cart', :to => '/spree/orders#update', :as => :update_cart
  put '/cart/empty', :to => '/spree/orders#empty', :as => :empty_cart

  # route globbing for pretty nested taxon and product paths
  get '/t/*id', :to => '/spree/taxons#show', :as => :nested_taxons

  get '/unauthorized', :to => '/spree/home#unauthorized', :as => :unauthorized
  get '/content/cvv', :to => '/spree/content#cvv', :as => :cvv
  get '/content/*path', :to => '/spree/content#show', :as => :content
  get '/cart_link', :to => '/spree/store#cart_link', :as => :cart_link
end
