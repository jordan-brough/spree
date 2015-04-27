require 'spec_helper'

RSpec.feature "Quantity Promotions" do
  given(:action) do
    Spree::Promotion::Actions::CreateQuantityAdjustments.create(
      calculator: calculator,
      preferred_group_size: 2
    )
  end

  given(:promotion) { FactoryGirl.create(:promotion, code: "PROMO") }
  given(:calculator) { FactoryGirl.create(:calculator, preferred_amount: 5) }

  background do
    FactoryGirl.create(:product, name: "DL-44")
    FactoryGirl.create(:product, name: "DL-55")
    promotion.actions << action

    visit spree.root_path
    click_link "DL-44"
    click_button "Add To Cart"
  end

  scenario "adding and removing items from the cart" do
    # Attempt to use the code with too few items.
    fill_in "Coupon code", with: "PROMO"
    click_button "Update"
    expect(page).to have_content("This coupon code could not be applied to the cart at this time")

    # Add another item to our cart.
    visit spree.root_path
    click_link "DL-44"
    click_button "Add To Cart"

    # Using the code should now succeed.
    fill_in "Coupon code", with: "PROMO"
    click_button "Update"
    expect(page).to have_content("The coupon code was successfully applied to your order")
    within("#cart_adjustments") do
      expect(page).to have_content("-$10.00")
    end

    # Reduce quantity by 1, making promotion not apply.
    fill_in "order_line_items_attributes_0_quantity", with: 1
    click_button "Update"
    within("#cart_adjustments") do
      expect(page).to have_content("$0.00")
    end

    # Bump quantity to 3, making promotion apply "once."
    fill_in "order_line_items_attributes_0_quantity", with: 3
    click_button "Update"
    within("#cart_adjustments") do
      expect(page).to have_content("-$10.00")
    end

    # Bump quantity to 4, making promotion apply "twice."
    fill_in "order_line_items_attributes_0_quantity", with: 4
    click_button "Update"
    within("#cart_adjustments") do
      expect(page).to have_content("-$20.00")
    end
  end

  scenario "bug" do
    # Get 3 of the item in our cart (2 of them should qualify for the discount)
    visit spree.root_path
    click_link "DL-44"
    fill_in "quantity", with: "2"
    click_button "Add To Cart"

    # Apply the promo code and see a $10 discount (for 2 of the 3 items)
    fill_in "Coupon code", with: "PROMO"
    click_button "Update"
    expect(page).to have_content("The coupon code was successfully applied to your order")
    within("#cart_adjustments") do
      expect(page).to have_content("-$10.00")
    end

    # Add a different product to our cart with quantity=2.
    # Expected:
    #   Total discount of $20 (for 4 of the 5 items)
    # Actual:
    #   Total discount of $15
    visit spree.root_path
    click_link "DL-55"
    fill_in "quantity", with: "2"
    click_button "Add To Cart"

    within("#cart_adjustments") do
      # This fails:
      expect(page).to have_content("-$20.00")
    end
  end
end

