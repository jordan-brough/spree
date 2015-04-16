require 'spec_helper'

describe Spree::PromotionCode do
  context 'callbacks' do
    subject { promotion_code.save }

    describe '#downcase_value' do
      let(:promotion) { create(:promotion, code: 'NewCoDe') }
      let(:promotion_code) { promotion.codes.first }

      it 'downcases the value before saving' do
        subject
        expect(promotion_code.value).to eq('newcode')
      end
    end
  end

  context "#usage_limit_exceeded?" do
    subject { promotion_code.usage_limit_exceeded?(promotable) }

    let(:promotion) { create(:promotion, :with_order_adjustment, per_code_usage_limit: per_code_usage_limit) }
    let(:promotion_code) { create(:promotion_code, promotion: promotion) }
    let(:promotable) { create(:order) }
    let(:order) { create(:completed_order_with_totals) }

    context "there is a usage limit set" do
      let!(:existing_adjustment) do
        Spree::Adjustment.create!(label: 'Adjustment', amount: 1, source: promotion.actions.first, promotion_code: promotion_code, adjustable: order, order: order)
      end

      context "the usage limit is not exceeded" do
        let(:per_code_usage_limit) { 10 }

        it "returns false" do
          expect(subject).to be_falsey
        end
      end

      context "the usage limit is exceeded" do
        let(:per_code_usage_limit) { 1 }

        context "for a different order" do
          it "returns true" do
            expect(subject).to be(true)
          end
        end

        context "for the same order" do
          let!(:existing_adjustment) do
            Spree::Adjustment.create!(adjustable: promotable, label: 'Adjustment', amount: 1, source: promotion.actions.first, promotion_code: promotion_code, order: promotable)
          end

          it "returns false" do
            expect(subject).to be(false)
          end
        end
      end
    end

    context "there is no usage limit set" do
      let(:per_code_usage_limit) { nil }

      it "returns false" do
        expect(subject).to be_falsey
      end
    end
  end

  describe "#usage_count" do
    let(:promotion) { FactoryGirl.create(:promotion, :with_order_adjustment, code: "discount") }
    let(:code) { promotion.codes.first }

    subject { code.usage_count }

    context "when the code is applied to a non-complete order" do
      let(:order) { FactoryGirl.create(:order_with_line_items) }
      before { promotion.activate(order: order, promotion_code: code) }
      it { is_expected.to eq 0 }
    end
    context "when the code is applied to a complete order" do
      context "and the promo is eligible" do
        let!(:order) { FactoryGirl.create(:completed_order_with_promotion, promotion: promotion) }
        it { is_expected.to eq 1 }
      end
      context "and the promo is ineligible" do
        let!(:order) { FactoryGirl.create(:completed_order_with_promotion, promotion: promotion) }
        before { order.adjustments.promotion.update_all(eligible: false) }
        it { is_expected.to eq 0 }
      end
    end
  end
end
