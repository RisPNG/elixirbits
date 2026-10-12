defmodule Elixirbits.Organizations do
  use Ash.Domain,
    otp_app: :elixirbits,
    extensions: [AshPaperTrail.Domain]

  paper_trail do
    include_versions? true
  end

  resources do
    resource Elixirbits.Organizations.Organization do
      define :current_organization, action: :current
      define :organization_settings, action: :settings, not_found_error?: false
      define :create_organization, action: :create
      define :update_organization, action: :update
    end
  end
end
