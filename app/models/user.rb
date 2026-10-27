# frozen_string_literal: true

class User < ApplicationRecord
  belongs_to :workspace
  has_many :sessions, dependent: :destroy
  has_secure_password
  normalizes :email, with: ->(value) { value.strip.downcase }
  validates :name, :email, presence: true
  validates :email, uniqueness: true
  validates :role, inclusion: { in: %w[reviewer viewer] }
  validates :password, length: { minimum: 12 }, allow_nil: true
end
