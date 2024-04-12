# frozen_string_literal: true

require 'test_helper'

class ExpendituresControllerTest < ActionDispatch::IntegrationTest
  def sign_in_as_admin_user
    admin_user = User.create!(
      entra_user_id: '0000',
      email: 'admin@localhost',
      first_name: 'Admin', last_name: 'User',
      role: :admin
    )

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:microsoft_identity_platform] = {
      provider: :microsoft_identity_platform,
      uid: admin_user.entra_user_id
    }.stringify_keys

    Rails.application.env_config['omniauth.auth'] = OmniAuth.config.mock_auth[:microsoft_identity_platform]
    post '/auth/microsoft_identity_platform'
    follow_redirect!
    assert_redirected_to root_path
  end

  def setup
    sign_in_as_admin_user

    Setting.create!(key: :current_year, value: Date.today.year)
    FinancingSource.create!(name: 'Buget')
    ExpenditureArticle.create!(code: '1', name: 'Cheltuială')
    PaymentType.create!(name: 'Transfer bancar')
  end

  test 'rolls back transaction if auditing record fails to save' do
    expenditure = build(:expenditure)
    expenditure_params = expenditure.attributes.symbolize_keys.slice(
      :registration_date,
      :financing_source_id,
      :project_category_id,
      :expenditure_article_id,
      :details,
      :procurement_type,
      :ordinance_number,
      :ordinance_date,
      :value,
      :payment_type_id,
      :beneficiary,
      :invoice,
      :noncompliance,
      :remarks
    )
    params = {
      expenditure: expenditure_params
    }

    assert_empty Expenditure.all

    AuditEvent.stub(:create!, ->(**_args) { raise ActiveRecord::RecordInvalid }) do
      post(expenditures_path, params:)
      assert_response :unprocessable_entity
    end

    assert_empty Expenditure.all
  end
end
