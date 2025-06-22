# frozen_string_literal: true

def seed_roles
  Role.find_or_create_by! name: 'Employee'
  Role.find_or_create_by! name: 'Supervisor'
  Role.find_or_create_by! name: 'Administrator'
end

def seed_roles_permissions
  # Common permissions
  Role.find_each do |role|
    # Every role should be allowed to view all the data
    %w[
      User ExpenditureArticle FinancingSource PaymentType
      ProjectCategory Expenditure Commitment AuditEvent Setting
    ].each do |entity_name|
      permission = Permission.find_by! name: "#{entity_name}.View"
      RolesPermission.find_or_create_by!(role:, permission:)
    end

    # Every role should be allowed to create expenditures and commitments
    %w[Expenditure Commitment].each do |entity_name|
      permission = Permission.find_by! name: "#{entity_name}.Create"
      RolesPermission.find_or_create_by!(role:, permission:)
    end

    # Everyone should be allowed to generate reports
    permission = Permission.find_by! name: 'Report.Generate'
    RolesPermission.create_or_find_by!(role:, permission:)
  end

  # Supervisors and administrators have more permissions
  %w[Supervisor Administrator].each do |role_name|
    role = Role.find_by! name: role_name

    # They can change app-wide settings
    permission = Permission.find_by! name: 'Setting.Edit'
    RolesPermission.create_or_find_by!(role:, permission:)

    # They can create, edit and delete misc entities
    %w[User ExpenditureArticle FinancingSource PaymentType ProjectCategory].each do |entity_name|
      %w[Create Edit Delete].each do |action_name|
        permission = Permission.find_by! name: "#{entity_name}.#{action_name}"
        RolesPermission.create_or_find_by!(role:, permission:)
      end
    end

    # They can edit existing expenditures and commitments, as well as import them from file
    %w[Expenditure Commitment].each do |entity_name|
      %w[Edit Import].each do |action_name|
        permission = Permission.find_by! name: "#{entity_name}.#{action_name}"
        RolesPermission.create_or_find_by!(role:, permission:)
      end
    end
  end
end
