module Spree
  module Api
    class ShipmentsController < Spree::Api::BaseController

      before_filter :load_shipment_and_order, only: [:update, :ready, :ship, :add, :remove]
      before_filter :load_order, only: :create
      before_filter :update_shipment, only: [:ready, :ship, :add, :remove]

      around_filter :lock_order

      def create
        authorize! :read, @order
        authorize! :create, Shipment
        variant = Spree::Variant.find(params[:variant_id])
        quantity = params[:quantity].to_i
        @shipment = @order.shipments.create(stock_location_id: params[:stock_location_id])
        @order.contents.add(variant, quantity, nil, @shipment)

        @shipment.refresh_rates
        @shipment.save!

        respond_with(@shipment.reload, default_template: :show)
      end

      def update
        @shipment.update_attributes_and_order(shipment_params)

        respond_with(@shipment.reload, default_template: :show)
      end

      def ready
        unless @shipment.ready?
          if @shipment.can_ready?
            @shipment.ready!
          else
            render 'spree/api/shipments/cannot_ready_shipment', status: 422 and return
          end
        end
        respond_with(@shipment, default_template: :show)
      end

      def ship
        unless @shipment.shipped?
          @shipment.ship!
        end
        respond_with(@shipment, default_template: :show)
      end

      def add
        variant = Spree::Variant.find(params[:variant_id])
        quantity = params[:quantity].to_i

        @shipment.order.contents.add(variant, quantity, nil, @shipment)

        respond_with(@shipment, default_template: :show)
      end

      def remove
        variant = Spree::Variant.find(params[:variant_id])
        quantity = params[:quantity].to_i

        @shipment.order.contents.remove(variant, quantity, @shipment)
        @shipment.reload if @shipment.persisted?
        respond_with(@shipment, default_template: :show)
      end

      private

      def load_shipment_and_order
        @shipment = Spree::Shipment.accessible_by(current_ability, :update).readonly(false).find_by!(number: params[:id])
        @order = @shipment.order
      end

      def update_shipment
        @shipment.update_attributes(shipment_params)
        @shipment.reload
      end

      def shipment_params
        if params[:shipment] && !params[:shipment].empty?
          params.require(:shipment).permit(permitted_shipment_attributes)
        else
          {}
        end
      end

      def load_order
        @order = Spree::Order.find_by!(number: params[:shipment][:order_id])
      end
    end
  end
end
