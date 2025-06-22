# frozen_string_literal: true

class ReportsController < ApplicationController
  VALID_TRIMESTERS = %w[I II III IV].freeze

  before_action -> { require_permission 'Report.Generate' }, only: %i[generate_pfc_activity_report pfc_activity_report]

  def generate_pfc_activity_report
    return unless request.post?

    year = params[:year]
    if year.blank?
      flash[:alert] = 'Vă rog să introduceți un an valid.'
      return
    end

    trimester = params[:trimester]
    if trimester.blank?
      flash[:alert] = 'Vă rog să selectați un trimestru valid.'
      return
    end

    redirect_to download_pfc_activity_report_path(year:, trimester:)
  end

  def pfc_activity_report
    @trimester = params.require(:trimester)
    return render nothing: true, status: :bad_request unless @trimester.in? VALID_TRIMESTERS

    @year = Integer(params.require(:year))
    return render nothing: true, status: :bad_request unless @year.in? 2010...3000

    respond_to do |format|
      format.xlsx do
        first_month = case @trimester
                      when 'I'
                        1
                      when 'II'
                        4
                      when 'III'
                        7
                      else
                        10
                      end

        start_date = Date.new(@year, first_month, 1).beginning_of_day
        end_date = Date.new(@year, first_month + 2, -1).end_of_day
        @expenditures = Expenditure.joins(:expenditure_article)
                                   .where(registration_date: start_date...end_date)
        @commitments = Commitment.joins(:expenditure_article)
                                 .where(registration_date: start_date...end_date)

        filename = "Raport activitate CFP trimestrul #{@trimester} #{@year}.xlsx"
        response.headers['Content-Disposition'] = "attachment; filename=\"#{filename}\""

        render :pfc_activity_report, formats: :xlsx
      end
    end
  end
end
