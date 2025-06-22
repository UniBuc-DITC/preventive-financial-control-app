# frozen_string_literal: true

class Permission < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  has_many  :roles, through: :roles_permissions
end
