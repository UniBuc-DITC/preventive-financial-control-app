# frozen_string_literal: true

class SettingsController < ApplicationController
  SETTINGS_CLASS = Class.new do
    include ActiveModel::Model

    def self.name
      'settings'
    end

    attr_accessor :current_year
  end

  private_constant :SETTINGS_CLASS

  before_action -> { require_permission 'Setting.View' }, only: %i[index]
  before_action -> { require_permission 'Setting.Edit' }, only: %i[update]

  def index
    @settings = SETTINGS_CLASS.new
    @settings.current_year = Setting.current_year
  end

  def update
    @settings = SETTINGS_CLASS.new(params.expect(settings: [:current_year]))

    setting = Setting.find_by!(key: :current_year)

    setting.update! value: @settings.current_year

    flash[:notice] = 'Setările au fost actualizate cu succes.'

    redirect_to :settings
  end
end
