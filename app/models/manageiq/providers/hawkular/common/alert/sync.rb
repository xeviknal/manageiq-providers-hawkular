module ManageIQ::Providers::Hawkular::Common::Alert::Sync
  extend ActiveSupport::Concern

  included do
    after_create_commit :sync_alerts
  end

  def sync_profile(alert_profile)
    alert_profile.members.each do |alert|
      sync_alert(alert)
    end
  end

  def sync_alert(alert)
    # Call ruby client
  end

  private

  def sync_alerts
  end
end
