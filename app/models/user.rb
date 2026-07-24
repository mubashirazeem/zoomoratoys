# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :trackable

  has_many :orders, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_one :cart, dependent: :destroy
  has_many :addresses, dependent: :destroy
  has_many :wishlist_items, dependent: :destroy
  has_many :wishlisted_products, through: :wishlist_items, source: :product

  validates :first_name, presence: true
  validates :last_name, presence: true

  # Admin customer search — name or email, same bound-parameter,
  # %/_-escaped pattern as Product.search.
  scope :search, ->(query) {
    pattern = "%#{sanitize_sql_like(query.to_s.strip)}%"
    where("first_name ILIKE :pattern OR last_name ILIKE :pattern OR email ILIKE :pattern", pattern: pattern)
  }

  def full_name
    "#{first_name} #{last_name}".strip
  end
end
