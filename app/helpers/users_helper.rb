# frozen_string_literal: true

module UsersHelper
  def selectable_roles
    roles = []

    if current_user.supervisor?
      roles << 'employee'
      roles << 'supervisor'
    end

    if current_user.admin?
      roles << 'employee'
      roles << 'supervisor'
      roles << 'admin'
    end

    roles
  end
end
