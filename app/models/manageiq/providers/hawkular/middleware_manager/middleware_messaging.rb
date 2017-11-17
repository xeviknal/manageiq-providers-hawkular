module ManageIQ::Providers
  class Hawkular::MiddlewareManager::MiddlewareMessaging < MiddlewareMessaging
    include ManageIQ::Providers::Hawkular::Common::Alert::Sync
  end
end
