# frozen_string_literal: true

class RolesPermission < ApplicationRecord
  belongs_to :role
  belongs_to :permission
end
