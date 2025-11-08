# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

def create_admin_user_account(admin_user_principal_name)
  identity_platform_credentials = Rails.application.credentials.microsoft_identity_platform

  raise StandardError, 'Microsoft Graph credentials are missing' if identity_platform_credentials.blank?

  # Create a new client context for authentication as an app
  context = MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new(
    identity_platform_credentials[:tenant_id],
    identity_platform_credentials[:client_id],
    identity_platform_credentials[:client_secret]
  )

  authentication_provider = MicrosoftGraphCore::Authentication::OAuthAuthenticationProvider.new(
    context,
    nil,
    ['https://graph.microsoft.com/.default']
  )

  adapter = MicrosoftGraph::GraphRequestAdapter.new(authentication_provider)
  client = MicrosoftGraph::GraphServiceClient.new(adapter)

  # Look up the user by their e-mail (User Principal Name)
  result = client.users.by_user_id(admin_user_principal_name).get.resume

  unless result
    raise StandardError,
          "User with e-mail address '#{admin_user_principal_name}' not found in Microsoft 365"
  end

  admin_entra_user_id = result.id
  admin = User.find_or_initialize_by(entra_user_id: admin_entra_user_id)

  admin.role = Role.find_by!(name: 'Administrator')

  if admin.persisted?
    Rails.logger.info { "The admin user account with ID #{admin_entra_user_id} already exists" }
  else
    Rails.logger.info 'Creating new admin user account...'

    admin.entra_user_id = result.id
    admin.email = result.mail
    admin.first_name = result.given_name
    admin.last_name = result.surname
  end

  admin.save!
end

# Initialize the current year setting
current_year_setting = Setting.find_or_initialize_by(key: :current_year)
unless current_year_setting.persisted?
  Rails.logger.info 'Initializing current year setting...'

  current_year_setting.value = Time.zone.today.year
  current_year_setting.save!
end

# Load the seed data
seed_files_directory = Rails.root / 'db' / 'seeds'

csv_reader_options = {
  headers: true,
  converters: ->(f) { f&.strip }
}

Rails.logger.info 'Seeding financing sources...'

CSV.foreach(seed_files_directory / 'financing_sources.csv', **csv_reader_options) do |row|
  name = row[0]
  Rails.logger.info { "Creating financing source '#{name}'" }
  FinancingSource.find_or_create_by!(name:)
end

Rails.logger.info 'Seeding project categories...'

CSV.foreach(seed_files_directory / 'project_categories.csv', **csv_reader_options) do |row|
  name = row[0]
  Rails.logger.info { "Creating project category '#{name}'" }
  ProjectCategory.find_or_create_by!(name:)
end

Rails.logger.info 'Seeding expenditure articles...'

CSV.foreach(seed_files_directory / 'expenditure_articles.csv', **csv_reader_options) do |row|
  code = row[0]
  name = row[1]
  expenditure_category_code = row[2]
  commitment_category_code = row[3]
  Rails.logger.info { "Creating expenditure article with code '#{code}', name '#{name}'" }
  expenditure_article = ExpenditureArticle.find_or_initialize_by(code:)
  expenditure_article.name = name
  expenditure_article.expenditure_category_code = expenditure_category_code
  expenditure_article.commitment_category_code = commitment_category_code
  expenditure_article.save!
end

Rails.logger.info 'Seeding payment methods...'

PREDEFINED_PAYMENT_METHODS = ['Avans numerar', 'Avans virament', 'Numerar', 'Virament'].freeze

PREDEFINED_PAYMENT_METHODS.each do |name|
  Rails.logger.info { "Creating project category '#{name}'" }
  PaymentType.find_or_create_by!(name:)
end

require_relative 'seed_permissions'

Rails.logger.info 'Seeding permissions...'

seed_permissions

require_relative 'seed_roles'

Rails.logger.info 'Seeding roles...'

seed_roles

Rails.logger.info 'Seeding role-permission associations...'

seed_roles_permissions

Rails.logger.info 'Seeding admin user...'

admin_user_email = ENV.fetch('ADMIN_EMAIL', nil)

if admin_user_email.blank?
  Rails.logger.info 'The `ADMIN_EMAIL` environment variable is blank, not creating admin user'
else
  begin
    create_admin_user_account(admin_user_email)
  rescue StandardError => e
    Rails.logger.error "Could not create admin user: #{e}"
  end
end
