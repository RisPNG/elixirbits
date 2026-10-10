defmodule Elixirbits.Organisations do
  use Ash.Domain,
    otp_app: :elixirbits,
    extensions: [AshPaperTrail.Domain]

  paper_trail do
    include_versions? true
  end

  resources do
    resource Elixirbits.Organisations.Organisation do
      define :current_organisation, action: :current
      define :organisation_settings, action: :settings, not_found_error?: false
      define :create_organisation, action: :create
      define :update_organisation, action: :update
    end
  end
end
