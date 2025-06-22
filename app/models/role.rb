# frozen_string_literal: true

class Role < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  has_many :users, dependent: :restrict_with_error
  has_many :roles_permissions
  has_many :permissions, through: :roles_permissions
end
