# frozen_string_literal: true

def seed_permissions
  %w[User ExpenditureArticle FinancingSource PaymentType ProjectCategory].each do |entity_name|
    %w[Create View Edit Delete].each do |action_name|
      Permission.find_or_create_by! name: "#{entity_name}.#{action_name}"
    end
  end

  %w[Expenditure Commitment].each do |entity_name|
    %w[Create View Edit Import].each do |action_name|
      Permission.find_or_create_by! name: "#{entity_name}.#{action_name}"
    end
  end

  Permission.find_or_create_by! name: 'AuditEvent.View'
  Permission.find_or_create_by! name: 'Setting.View'
  Permission.find_or_create_by! name: 'Setting.Edit'
  Permission.find_or_create_by! name: 'Report.Generate'
end
