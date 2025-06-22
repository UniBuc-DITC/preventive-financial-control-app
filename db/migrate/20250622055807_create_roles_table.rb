# frozen_string_literal: true

class CreateRolesTable < ActiveRecord::Migration[8.0]
  def up
    create_table :permissions do |t|
      t.string :name, null: false
      t.index :name, unique: true
      t.timestamps
    end

    %w[User ExpenditureArticle FinancingSource PaymentType ProjectCategory].each do |entity_name|
      %w[Create View Edit Delete].each do |action_name|
        execute <<-SQL.squish
          INSERT INTO permissions (name, created_at, updated_at)
          VALUES ('#{entity_name}.#{action_name}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        SQL
      end
    end

    %w[Expenditure Commitment].each do |entity_name|
      %w[Create View Edit Import].each do |action_name|
        execute <<-SQL.squish
          INSERT INTO permissions (name, created_at, updated_at)
          VALUES ('#{entity_name}.#{action_name}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        SQL
      end
    end

    %w[AuditEvent.View Setting.View Setting.Edit Report.Generate].each do |permission_name|
      execute <<-SQL.squish
        INSERT INTO permissions (name, created_at, updated_at)
        VALUES ('#{permission_name}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL
    end

    create_table :roles do |t|
      t.string :name, null: false
      t.index :name, unique: true
      t.timestamps
    end

    %w[Employee Supervisor Administrator].each do |role_name|
      execute "INSERT INTO roles (name, created_at, updated_at) VALUES ('#{role_name}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
    end

    create_join_table :roles, :permissions, table_name: 'roles_permissions' do |t|
      t.foreign_key :roles
      t.foreign_key :permissions
      t.index :role_id
      t.index :permission_id
      t.index %i[role_id permission_id], unique: true
    end

    get_query_item = lambda { |sql_string|
      result = query(sql_string).first

      raise StandardError, "Query returned no results: '#{sql_string}'" if result.nil?

      result.first
    }
    get_role_id = ->(name) { get_query_item.call "SELECT id FROM roles WHERE name = '#{name}'" }
    get_permission_id = ->(name) { get_query_item.call "SELECT id FROM permissions WHERE name = '#{name}'" }

    # Common permissions
    %w[Employee Supervisor Administrator].each do |role_name|
      role_id = get_role_id.call role_name

      # Every role should be allowed to view all the data
      %w[
        User ExpenditureArticle FinancingSource PaymentType
        ProjectCategory Expenditure Commitment AuditEvent Setting
      ].each do |entity_name|
        permission_id = get_permission_id.call "#{entity_name}.View"
        execute "INSERT INTO roles_permissions (role_id, permission_id) VALUES (#{role_id}, #{permission_id})"
      end

      # Every role should be allowed to create expenditures and commitments
      %w[Expenditure Commitment].each do |entity_name|
        permission_id = get_permission_id.call "#{entity_name}.Create"
        execute "INSERT INTO roles_permissions (role_id, permission_id) VALUES (#{role_id}, #{permission_id})"
      end

      # Everyone should be allowed to generate reports
      permission_id = get_permission_id.call 'Report.Generate'
      execute "INSERT INTO roles_permissions (role_id, permission_id) VALUES (#{role_id}, #{permission_id})"
    end

    # Supervisors and administrators have more permissions
    %w[Supervisor Administrator].each do |role_name|
      role_id = get_role_id.call role_name

      # They can change app-wide settings
      permission_id = get_permission_id.call 'Setting.Edit'
      execute "INSERT INTO roles_permissions (role_id, permission_id) VALUES (#{role_id}, #{permission_id})"

      # They can create, edit and delete misc entities
      %w[User ExpenditureArticle FinancingSource PaymentType ProjectCategory].each do |entity_name|
        %w[Create Edit Delete].each do |action_name|
          permission_id = get_permission_id.call "#{entity_name}.#{action_name}"
          execute "INSERT INTO roles_permissions (role_id, permission_id) VALUES (#{role_id}, #{permission_id})"
        end
      end

      # They can edit existing expenditures and commitments, as well as import them from file
      %w[Expenditure Commitment].each do |entity_name|
        %w[Edit Import].each do |action_name|
          permission_id = get_permission_id.call "#{entity_name}.#{action_name}"
          execute "INSERT INTO roles_permissions (role_id, permission_id) VALUES (#{role_id}, #{permission_id})"
        end
      end
    end

    add_belongs_to :users, :role, foreign_key: true

    role_mapping = {
      'employee' => 'Employee',
      'supervisor' => 'Supervisor',
      'admin' => 'Administrator'
    }.freeze

    role_mapping.each_pair do |old_role_name, new_role_name|
      execute <<-SQL.squish
        UPDATE users
        SET role_id = (SELECT id FROM roles WHERE name = '#{new_role_name}')
        WHERE role = '#{old_role_name}'
      SQL
    end

    change_table :users, bulk: true do |t|
      t.change_null :role_id, false
      t.remove :role
    end
  end

  def down
    add_column :users, :role, :string

    role_mapping = {
      'Employee' => 'employee',
      'Supervisor' => 'supervisor',
      'Administrator' => 'admin'
    }.freeze

    role_mapping.each_pair do |new_role_name, old_role_name|
      execute <<-SQL.squish
        UPDATE users
        SET role = '#{old_role_name}'
        WHERE role_id = (SELECT id FROM roles WHERE name = '#{new_role_name}')
      SQL
    end

    change_column_null :users, :role, false

    remove_belongs_to :users, :role, foreign_key: true
    drop_join_table :roles, :permissions, table_name: 'roles_permissions'
    drop_table :roles
    drop_table :permissions
  end
end
