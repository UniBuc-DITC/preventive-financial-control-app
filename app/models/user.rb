# frozen_string_literal: true

class User < ApplicationRecord
  ROLES = %i[employee supervisor admin].freeze

  enum role: ROLES.zip(ROLES).to_h

  validates :entra_user_id, :email, :first_name, :last_name,
            presence: true

  def full_name
    "#{first_name} #{last_name}"
  end
end
