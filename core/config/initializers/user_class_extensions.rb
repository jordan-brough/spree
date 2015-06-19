Spree::Core::Engine.config.to_prepare do
  if Spree.user_class
    Spree.user_class.class_eval do

      include Spree::UserReporting
      include Spree::UserApiAuthentication
      has_many :role_users, foreign_key: "user_id", class_name: "Spree::RoleUser"
      has_many :spree_roles, through: :role_users, source: :role

      has_many :user_stock_locations, foreign_key: "user_id", class_name: "Spree::UserStockLocation"
      has_many :stock_locations, through: :user_stock_locations

      has_many :spree_orders, :foreign_key => "user_id", :class_name => "Spree::Order"

      belongs_to :ship_address, :class_name => 'Spree::Address'
      belongs_to :bill_address, :class_name => 'Spree::Address'

      # has_spree_role? simply needs to return true or false whether a user has a role or not.
      def has_spree_role?(role_in_question)
        spree_roles.where(:name => role_in_question.to_s).any?
      end

      def last_incomplete_spree_order
        spree_orders.incomplete.where(:created_by_id => self.id).where(frontend_viewable: true).order('created_at DESC').first
      end
    end
  end
end
