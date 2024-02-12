# frozen_string_literal: true

require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'can create user' do
    user = User.new(
      entra_user_id: SecureRandom.uuid,
      email: 'test.user@example.com',
      given_name: 'Test',
      family_name: 'User',
      role: :supervisor,
    )

    assert user.save
  end
end
