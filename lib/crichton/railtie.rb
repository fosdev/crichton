require 'crichton/helpers'
require 'crichton/middleware/registry_cleaner'
require 'crichton/middleware/alps_profile_response'
require 'crichton/middleware/resource_home_response'

module Crichton
  class Railtie < Rails::Railtie
    include Crichton::Helpers::ConfigHelper

    initializer "crichton.insert_middleware" do |app|
      app.config.middleware.use "Crichton::Middleware::RegistryCleaner" if Rails.env.development?
    end
  end
end
