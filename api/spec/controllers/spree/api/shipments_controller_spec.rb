require 'spec_helper'

describe Spree::Api::ShipmentsController do
  render_views
  let!(:shipment) { create(:shipment, inventory_units: [build(:inventory_unit, shipment: nil)]) }
  let!(:attributes) { [:id, :tracking, :number, :cost, :shipped_at, :stock_location_name, :order_id, :shipping_rates, :shipping_methods] }

  before do
    stub_authentication!
  end

  let!(:resource_scoping) { { id: shipment.to_param, shipment: { order_id: shipment.order.to_param } } }

  context "as a non-admin" do
    it "cannot make a shipment ready" do
      api_put :ready
      assert_not_found!
    end

    it "cannot make a shipment shipped" do
      api_put :ship
      assert_not_found!
    end
  end

  context "as an admin" do
    let!(:order) { shipment.order }
    let!(:stock_location) { create(:stock_location_with_items) }
    let!(:variant) { create(:variant) }
    sign_in_as_admin!

    it 'can create a new shipment' do
      params = {
        variant_id: stock_location.stock_items.first.variant.to_param,
        shipment: { order_id: order.number },
        stock_location_id: stock_location.to_param,
      }

      api_post :create, params
      response.status.should == 200
      json_response.should have_attributes(attributes)
    end

    it 'can update a shipment' do
      params = {
        shipment: {
          stock_location_id: stock_location.to_param
        }
      }

      api_put :update, params
      response.status.should == 200
      json_response['stock_location_name'].should == stock_location.name
    end

    it "can make a shipment ready" do
      Spree::Order.any_instance.stub(:paid? => true, :complete? => true)
      api_put :ready
      json_response.should have_attributes(attributes)
      json_response["state"].should == "ready"
      shipment.reload.state.should == "ready"
    end

    it "cannot make a shipment ready if the order is unpaid" do
      Spree::Order.any_instance.stub(:paid? => false)
      api_put :ready
      json_response["error"].should == "Cannot ready shipment."
      response.status.should == 422
    end

    context 'for completed orders' do
      let(:order) { create :completed_order_with_totals }
      let!(:resource_scoping) { { id: order.shipments.first.to_param, shipment: { order_id: order.to_param } } }

      it 'adds a variant to a shipment' do
        api_put :add, { variant_id: variant.to_param, quantity: 2 }
        response.status.should == 200
        json_response['manifest'].detect { |h| h['variant']['id'] == variant.id }["quantity"].should == 2
      end

      it 'removes a variant from a shipment' do
        order.contents.add(variant, 2)

        api_put :remove, { variant_id: variant.to_param, quantity: 1 }
        response.status.should == 200
        json_response['manifest'].detect { |h| h['variant']['id'] == variant.id }["quantity"].should == 1
      end
    end

    context "for shipped shipments" do
      let(:order) { create :shipped_order }
      let!(:resource_scoping) { { id: order.shipments.first.to_param, shipment: { order_id: order.to_param } } }

      it 'adds a variant to a shipment' do
        api_put :add, { variant_id: variant.to_param, quantity: 2 }
        response.status.should == 200
        json_response['manifest'].detect { |h| h['variant']['id'] == variant.id }["quantity"].should == 2
      end

      it 'cannot remove a variant from a shipment' do
        api_put :remove, { variant_id: variant.to_param, quantity: 1 }
        response.status.should == 422
        expect(json_response['errors']['base'].join).to match /Cannot remove items/
      end

    end

    describe '#mine' do
      subject do
        api_get :mine, format: 'json', params: params
      end

      let(:params) { {} }

      before { subject }

      context "the current api user is authenticated and has orders" do
        let(:current_api_user) { shipped_order.user }
        let(:shipped_order) { create(:shipped_order) }

        it 'succeeds' do
          expect(response.status).to eq 200
        end

        describe 'json output' do
          render_views

          let(:rendered_shipment_ids) { json_response['shipments'].map { |s| s['id'] } }

          it 'contains the shipments' do
            expect(rendered_shipment_ids).to match_array current_api_user.orders.flat_map(&:shipments).map(&:id)
          end
        end

        context 'with filtering' do
          let(:params) { {q: {order_completed_at_not_null: 1}} }

          let!(:incomplete_order) { create(:order, user: current_api_user) }

          it 'filters' do
            expect(assigns(:shipments).map(&:id)).to match_array current_api_user.orders.complete.flat_map(&:shipments).map(&:id)
          end
        end
      end

      context "the current api user does not exist" do
        let(:current_api_user) { nil }

        it "returns a 401" do
          response.status.should == 401
        end
      end
    end

  end

  describe "#ship" do
    let(:shipment) { create(:order_ready_to_ship).shipments.first }

    let(:send_mailer) { nil }
    subject { api_put :ship, id: shipment.to_param, send_mailer: send_mailer }

    context "the user is allowed to ship the shipment" do
      sign_in_as_admin!
      it "ships the shipment" do
        Timecop.freeze do
          subject
          shipment.reload
          expect(shipment.state).to eq 'shipped'
          expect(shipment.shipped_at.to_i).to eq Time.now.to_i
        end
      end

      context "send_mailer not present" do
        it "sends the shipped shipments mailer" do
          with_test_mail { subject }
          expect(ActionMailer::Base.deliveries.size).to eq 1
          expect(ActionMailer::Base.deliveries.last.subject).to match /Shipment Notification/
        end
      end

      context "send_mailer set to false" do
        let(:send_mailer) { 'false' }
        it "does not send the shipped shipments mailer" do
          with_test_mail { subject }
          expect(ActionMailer::Base.deliveries.size).to eq 0
        end
      end

      context "send_mailer set to true" do
        let(:send_mailer) { 'true' }
        it "sends the shipped shipments mailer" do
          with_test_mail { subject }
          expect(ActionMailer::Base.deliveries.size).to eq 1
          expect(ActionMailer::Base.deliveries.last.subject).to match /Shipment Notification/
        end
      end
    end

    context "the user is not allowed to ship the shipment" do
      sign_in_as_admin!

      before do
        ability = Spree::Ability.new(current_api_user)
        ability.cannot :ship, Spree::Shipment
        allow(controller).to receive(:current_ability) { ability }
      end

      it "does nothing" do
        expect {
          expect {
            subject
          }.not_to change(shipment, :state)
        }.not_to change(shipment, :shipped_at)
      end

      it "responds with a 401" do
        subject
        expect(response.status).to eq 401
      end
    end

    context "the user is not allowed to view the shipment" do
      it "does nothing" do
        expect {
          expect {
            subject
          }.not_to change(shipment, :state)
        }.not_to change(shipment, :shipped_at)
      end

      it "responds with a 404" do
        subject
        expect(response).to be_not_found
      end
    end
  end
end
