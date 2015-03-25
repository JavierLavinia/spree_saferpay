Spree::Core::Engine.routes.draw do

  resources :orders do
    resource :checkout, controller: :checkout do
      member do
        get :saferpay_checkout
        get :saferpay_payment
        get :saferpay_confirm
        post :saferpay_notify
      end
    end
  end

end
