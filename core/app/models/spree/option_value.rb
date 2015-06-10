module Spree
  class OptionValue < ActiveRecord::Base
    belongs_to :option_type, class_name: 'Spree::OptionType', touch: true, inverse_of: :option_values
    acts_as_list scope: :option_type

    has_many :option_values_variants, dependent: :destroy
    has_many :variants, through: :option_values_variants

    validates :name, :presentation, presence: true

    after_touch :touch_all_variants

    def touch_all_variants
      # This can cause a cascade of products to be updated
      # To disable it in Rails 4.1, we can do this:
      # https://github.com/rails/rails/pull/12772
      # Spree::Product.no_touching do
        variants.find_each(&:touch)
      # end
    end

    def presentation_with_option_type
      "#{self.option_type.presentation} - #{self.presentation}"
    end
  end
end
