# frozen_string_literal: true

class User < ApplicationRecord
  belongs_to :role

  validates :entra_user_id, :email, :first_name, :last_name,
            :background_color, :text_color,
            presence: true

  def full_name
    "#{first_name} #{last_name}".titleize
  end
end
