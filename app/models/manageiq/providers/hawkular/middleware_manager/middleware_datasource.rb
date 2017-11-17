module ManageIQ::Providers
  class Hawkular::MiddlewareManager::MiddlewareDatasource < MiddlewareDatasource
    include ManageIQ::Providers::Hawkular::Common::Alert::Sync
  end
end
