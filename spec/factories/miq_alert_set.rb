FactoryGirl.define do
  factory :miq_alert_set_mw, :parent => :miq_alert_set do
    mode "MiddlewareServer"
  end

  factory :miq_alert_set_mw_server,
    :parent => :miq_alert_set,
    :class => 'ManageIQ::Providers::Hawkular::Alerting::MiddlewareAlertSet' do
    mode "MiddlewareServer"
  end
end
