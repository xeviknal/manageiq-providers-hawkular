module ManageIQ::Providers::Hawkular::Common::Alert::Sync
  extend ActiveSupport::Concern

  included do
    after_create_commit :sync_alerts
  end

  private

  def sync_alerts
  end
end
