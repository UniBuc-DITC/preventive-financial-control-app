# frozen_string_literal: true

require 'test_helper'

class ExpendituresControllerTest < ActionDispatch::IntegrationTest
  def sign_in_as_test_user
    role = Role.find_or_create_by!(name: 'Test user')

    %w[View Create Edit Import].each do |action_name|
      permission = Permission.find_or_create_by!(name: "Expenditure.#{action_name}")
      RolesPermission.create!(role:, permission:)
    end

    user = User.create!(
      entra_user_id: '0000',
      email: 'test@localhost',
      first_name: 'Test', last_name: 'User',
      role:
    )

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:microsoft_identity_platform] = {
      provider: :microsoft_identity_platform,
      uid: user.entra_user_id
    }.stringify_keys

    Rails.application.env_config['omniauth.auth'] = OmniAuth.config.mock_auth[:microsoft_identity_platform]
    post '/auth/microsoft_identity_platform'
    follow_redirect!
    assert_redirected_to root_path
  end

  def setup
    sign_in_as_test_user

    create(:setting, :current_year)
    create(:financing_source)
    create(:expenditure_article)
    create(:payment_type)
  end

  test 'can create new expenditure' do
    expenditure_params = attributes_for(:expenditure)
    expenditure_params[:financing_source_id] = FinancingSource.first.id
    expenditure_params[:expenditure_article_id] = ExpenditureArticle.first.id
    expenditure_params[:payment_type_id] = PaymentType.first.id
    params = {
      expenditure: expenditure_params
    }

    assert_empty Expenditure.all

    post(expenditures_path, params:)
    assert_response :redirect

    assert_redirected_to expenditures_path

    assert_not_empty Expenditure.all
  end

  test 'changing the current year resets the registration number' do
    # Create some fake entities
    create(:expenditure)
    create(:expenditure)

    assert_equal 2, Expenditure.count

    # Change the current year
    new_current_year = Time.zone.today.year + 1
    Setting.find_by!(key: :current_year).update!(value: new_current_year)

    expenditure_params = attributes_for(:expenditure)
    expenditure_params[:financing_source_id] = FinancingSource.first.id
    expenditure_params[:expenditure_article_id] = ExpenditureArticle.first.id
    expenditure_params[:payment_type_id] = PaymentType.first.id
    params = {
      expenditure: expenditure_params
    }

    post(expenditures_path, params:)
    assert_response :redirect

    assert_redirected_to expenditures_path

    new_expenditure = Expenditure.find_by(year: new_current_year)
    assert_not_nil new_expenditure
    assert_equal 1, new_expenditure.registration_number
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

  test 'can export expenditures' do
    create_list(:expenditure, 5)

    get export_download_expenditures_path
    assert_response :success
  end
end
