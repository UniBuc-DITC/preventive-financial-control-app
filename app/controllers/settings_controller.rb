# frozen_string_literal: true

class SettingsController < ApplicationController
  before_action :require_supervisor_or_admin

  SETTINGS_CLASS = Class.new do
    include ActiveModel::Model

    def self.name
      'settings'
    end

    attr_accessor :current_year
  end

  private_constant :SETTINGS_CLASS

  def index
    @settings = SETTINGS_CLASS.new
    @settings.current_year = Setting.current_year
  end

  def update
    @settings = SETTINGS_CLASS.new(params.require(:settings).permit(:current_year))

    setting = Setting.find_by!(key: :current_year)

    setting.update! value: @settings.current_year

    flash[:notice] = 'Setările au fost actualizate cu succes.'

    redirect_to :settings
  end
end
