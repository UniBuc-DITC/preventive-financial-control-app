# frozen_string_literal: true

class AuditEventsController < ApplicationController
  before_action -> { require_permission('AuditEvent.View') }, only: [:index]

  def index
    @audit_events = AuditEvent.order(timestamp: :desc)

    relation_names = %i[user]
    @audit_events = @audit_events.references(relation_names).includes(relation_names)

    @paginated_audit_events = @audit_events.paginate(page: params[:page])
  end
end
