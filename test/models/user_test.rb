# frozen_string_literal: true

require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'can create user' do
    role = create(:role)

    user = User.new(
      entra_user_id: SecureRandom.uuid,
      email: 'test.user@example.com',
      first_name: 'Test',
      last_name: 'User',
      role:,
    )

    assert user.save
  end
end
